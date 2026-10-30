*&---------------------------------------------------------------------*
*& Report Z_ABAPGIT_PULL_MCP_SHORTCUT
*&---------------------------------------------------------------------*
*&
*&---------------------------------------------------------------------*
REPORT z_abapgit_pull_mcp_shortcut LINE-SIZE 1023.

* Selection screen with readable labels and F4 help
SELECTION-SCREEN BEGIN OF BLOCK b1 WITH FRAME TITLE TEXT-001.
  PARAMETERS:
    p_action TYPE c LENGTH 4 DEFAULT 'PULL'.  " Action: PULL = pull repo, LIST = list all repos
  SELECTION-SCREEN COMMENT /1(60) gc_hint.     " Shows valid P_ACTION values
  PARAMETERS:
    p_repo   TYPE string LOWER CASE,           " Repository name or URL (PULL: this or P_KEY)
    p_key    TYPE string LOWER CASE,           " abapGit repository key (PULL: this or P_REPO)
    p_branch TYPE string LOWER CASE,           " Branch to switch to before the pull (optional)
    p_trkorr TYPE trkorr.                       " Transport request (F4 available)
SELECTION-SCREEN END OF BLOCK b1.

SELECTION-SCREEN BEGIN OF BLOCK b2 WITH FRAME TITLE TEXT-002.
  PARAMETERS:
    p_user  TYPE string LOWER CASE,             " GitHub username
    p_token TYPE string LOWER CASE.              " GitHub PAT (Personal Access Token)
SELECTION-SCREEN END OF BLOCK b2.

* State before the P_BRANCH switch. gv_switched = abap_true means: put the
* repository back on every failure after this point (see restore_branch).
DATA: gv_switched    TYPE abap_bool,
      gv_prev_branch TYPE string,
      gv_prev_commit TYPE string.

INITIALIZATION.
  gc_hint = 'Valid actions: PULL (pull repo) | LIST (list all repos)'.

AT SELECTION-SCREEN.
  IF p_action <> 'PULL' AND p_action <> 'LIST'.
    MESSAGE e398(00) WITH 'Invalid P_ACTION:' p_action '. Use PULL or LIST.' ''.
  ENDIF.

START-OF-SELECTION.

* --- LIST mode: output all registered repos as tilde-delimited lines ---
  IF p_action = 'LIST'.
    TRY.
        " The count goes FIRST, deliberately. The consumer reads only
        " the first page of this classic list, so a trailing total lands
        " on the page it never sees - which is exactly the case it would
        " be there to detect. As a header it is always visible, and the
        " consumer can compare it against the number of rows it parsed.
        "
        " Padded to the same eight fields as a repository line (see
        " ZCL_ABAPGIT_MCP_LIST_FMT), so a consumer that splits every line
        " blindly gets the same width, and one that looks for a header still
        " finds TOTAL in field 1. Fields may be appended; readers ignore
        " unknown trailing fields.
        DATA(lt_repos) = zcl_abapgit_repo_srv=>get_instance( )->list( ).
        WRITE: / zcl_abapgit_mcp_list_fmt=>header( lines( lt_repos ) ).

        LOOP AT lt_repos INTO DATA(li_repo_list).
          DATA(lv_offline) = li_repo_list->is_offline( ).
          DATA(lv_url) = COND string( WHEN lv_offline = abap_false
                                      THEN CAST zcl_abapgit_repo_online( li_repo_list )->get_url( )
                                      ELSE '' ).
          DATA(lv_ts) = COND string( WHEN li_repo_list->ms_data-deserialized_at IS NOT INITIAL
                                     THEN |{ li_repo_list->ms_data-deserialized_at }|
                                     ELSE '' ).
          DATA(lv_line) = zcl_abapgit_mcp_list_fmt=>repo_line(
                            iv_name            = li_repo_list->get_name( )
                            iv_url             = lv_url
                            iv_package         = li_repo_list->get_package( )
                            iv_branch          = li_repo_list->ms_data-branch_name
                            iv_deserialized_at = lv_ts
                            iv_deserialized_by = li_repo_list->ms_data-deserialized_by
                            iv_offline         = lv_offline
                            iv_key             = li_repo_list->ms_data-key ).
          WRITE: / lv_line.
        ENDLOOP.

      CATCH cx_root INTO DATA(lx_list_error).
        MESSAGE e398(00) WITH lx_list_error->get_text( ) '' '' ''.
    ENDTRY.
    RETURN.
  ENDIF.

* --- PULL mode ---
  " Exactly one selector: P_REPO (name or URL) or P_KEY (abapGit key). Never
  " both, even if they agree, and never a guess. A key is a string on purpose:
  " a c(12) parameter would cut a 13-digit input to 12 digits and bind another
  " repository.
  DATA(lv_selector_error) = zcl_abapgit_mcp_repo_match=>check_selector( iv_repo = p_repo
                                                                        iv_key  = p_key ).
  IF lv_selector_error IS NOT INITIAL.
    MESSAGE e398(00) WITH lv_selector_error '' '' ''.
    RETURN.
  ENDIF.

  TRY.
      DATA lo_repo TYPE REF TO zcl_abapgit_repo_online.

      " Match EXACTLY, on name or normalised URL, and refuse to guess.
      "
      " This was `IF li_repo->get_name( ) CS p_repo` with an EXIT on the
      " first hit. CS is a substring test AND ignores case, so a P_REPO
      " that was not unique silently bound an arbitrary repository - and
      " since this report auto-confirms every overwrite decision below
      " (it must, to run unattended), that meant deserializing over an
      " unrelated package and reporting success.
      "
      " The matching lives in ZCL_ABAPGIT_MCP_REPO_MATCH, so that this report and
      " the ADT endpoints under /sap/bc/adt/abapgitsync/ resolve a
      " repository the same way: name (case-insensitive) or URL without a
      " trailing slash and .git suffix, online repositories only.
      IF condense( p_key ) IS NOT INITIAL.
        " By key: unique by construction, so there is no ambiguity case.
        " The key is normalised (trimmed, padded to 12 digits); check_selector
        " has accepted it above.
        DATA(lv_key) = zcl_abapgit_mcp_repo_match=>normalise_key( p_key ).
        lo_repo = zcl_abapgit_mcp_repo_match=>find_online_repo_by_key( lv_key ).
        IF lo_repo IS NOT BOUND.
          DATA(lv_key_text) = |key { lv_key }|.
          MESSAGE e398(00) WITH 'Repository not found:' lv_key_text '(online only)' ''.
          RETURN.
        ENDIF.
      ELSE.
        DATA(lt_hits) = zcl_abapgit_mcp_repo_match=>find_online_repos( p_repo ).

        IF lines( lt_hits ) = 0.
          " Kept short on purpose: the status bar cuts at about 73
          " characters, and this is what the MCP consumer reads.
          MESSAGE e398(00) WITH 'Repository not found:' p_repo
                                '(exact name/URL, online only)' ''.
          RETURN.
        ENDIF.

        IF lines( lt_hits ) > 1.
          " Two repos may share a name, and abapGit permits the same
          " URL to be registered twice against different packages - so
          " neither comparand is guaranteed unique on its own.
          DATA(lv_hits) = |{ lines( lt_hits ) }|.
          MESSAGE e398(00) WITH 'P_REPO is ambiguous:' p_repo 'matches' lv_hits.
          RETURN.
        ENDIF.

        lo_repo = lt_hits[ 1 ].
      ENDIF.

      IF p_user IS NOT INITIAL AND p_token IS NOT INITIAL.
        zcl_abapgit_login_manager=>set(
          iv_uri      = lo_repo->get_url( )
          iv_username = p_user
          iv_password = p_token ).
      ENDIF.

      " Optional and persistent, like a switch in the abapGit UI. An unknown
      " branch changes nothing. Without P_BRANCH the repository is not touched.
      " The previous branch and pin are remembered first: every failure from here
      " on puts the repository back (PERFORM restore_branch), so a pull that did
      " not happen does not leave the repository on another branch. The switch
      " itself must stay before deserialize_checks( ), which depend on it.
      IF p_branch IS NOT INITIAL.
        gv_prev_branch = lo_repo->get_selected_branch( ).
        gv_prev_commit = lo_repo->get_selected_commit( ).
        gv_switched    = abap_true.
      ENDIF.
      IF p_branch IS NOT INITIAL
         AND zcl_abapgit_mcp_branch=>select( io_repo   = lo_repo
                                             iv_branch = p_branch ) = abap_false.
        MESSAGE e398(00) WITH 'Branch not found:' p_branch '(selected branch unchanged)' ''.
        RETURN.
      ENDIF.

      DATA(ls_checks) = lo_repo->deserialize_checks( ).

      IF ls_checks-transport-required = abap_true AND p_trkorr IS INITIAL.
        PERFORM restore_branch USING `Transport required`.
        MESSAGE e398(00) WITH 'Transport required. Provide P_TRKORR=' ls_checks-transport-type '' ''.
        RETURN.
      ENDIF.

      " Verify user has a modifiable task in the transport before deserialize.
      " Without this, deserialize silently succeeds but writes nothing.
      IF p_trkorr IS NOT INITIAL.
        SELECT SINGLE @abap_true FROM e070
          INTO @DATA(lv_task_exists)
          WHERE strkorr  = @p_trkorr
            AND as4user  = @sy-uname
            AND trstatus = 'D'.               " D = modifiable
        IF sy-subrc <> 0.
          PERFORM restore_branch USING `No modifiable task`.
          MESSAGE e398(00) WITH 'User' sy-uname 'has no modifiable task in' p_trkorr.
          RETURN.
        ENDIF.
      ENDIF.

      ls_checks-transport-transport = p_trkorr.

      " Auto-confirm all overwrite decisions (MCP automation requires non-interactive mode)
      " Decision values: ' ' = undecided, 'Y' = overwrite, 'N' = skip
      LOOP AT ls_checks-overwrite ASSIGNING FIELD-SYMBOL(<ls_overwrite>).
        <ls_overwrite>-decision = 'Y'.
      ENDLOOP.

      DATA lo_log TYPE REF TO zif_abapgit_log.
      lo_log = NEW zcl_abapgit_log( ).

      lo_repo->deserialize(
        is_checks = ls_checks
        ii_log    = lo_log ).

      " Check the deserialization log for errors/warnings.
      " See: https://github.com/abapGit/abapGit/issues/2495
      "      https://github.com/abapGit/abapGit/issues/2821
      DATA(lv_log_status) = lo_log->get_status( ).
      IF lv_log_status = zif_abapgit_log=>c_status-error
         OR lv_log_status = zif_abapgit_log=>c_status-warning.
        DATA(lt_msgs) = lo_log->get_messages( ).
        IF lines( lt_msgs ) > 0.
          DATA(lv_msg) = lt_msgs[ 1 ]-text.
          PERFORM restore_branch USING lv_msg.
          MESSAGE e398(00) WITH 'Pull log:' lv_msg '' ''.
        ELSE.
          PERFORM restore_branch USING `Deserialization log has issues`.
          MESSAGE e398(00) WITH 'Pull failed: deserialization log has issues' '' '' ''.
        ENDIF.
        RETURN.
      ENDIF.

      IF p_branch IS INITIAL.
        MESSAGE s398(00) WITH 'Pull successful:' lo_repo->get_name( ) '' ''.
      ELSE.
        " Only with P_BRANCH, so the message without it stays byte for byte the same.
        " The status bar is cut at about 73 characters, so the branch is also
        " written as a list line, which a consumer can read in full:
        "   BRANCH~<full ref>
        " The echo is what the repository is on, not what was asked for. A
        " consumer treats a missing or different echo as a failure.
        DATA(lv_branch_now) = lo_repo->get_selected_branch( ).
        DATA(lv_status_branch) = |Pull successful: branch={ lv_branch_now }|.
        DATA(lv_status_repo) = |repo={ lo_repo->get_name( ) }|.
        WRITE: / |BRANCH~{ lv_branch_now }|.
        MESSAGE s398(00) WITH lv_status_branch lv_status_repo '' ''.
      ENDIF.

    CATCH cx_root INTO DATA(lx_error).
      DATA(lv_cause) = lx_error->get_text( ).
      PERFORM restore_branch USING lv_cause.
      MESSAGE e398(00) WITH lx_error->get_text( ) '' '' ''.
  ENDTRY.

*&---------------------------------------------------------------------*
*& Puts the repository back on the branch and pin it had before the
*& P_BRANCH switch. Does nothing without a switch and when the repository
*& is there already. Never raises: the failure that made it run is what
*& gets reported - except when the restore itself fails: then the repository
*& is left on the new branch, which matters more, and the message says so
*& and names the original cause, all in the message text. (An information message would open a popup
*& that blocks an unattended consumer.)
*&---------------------------------------------------------------------*
FORM restore_branch USING iv_reason TYPE string.
  IF gv_switched = abap_false OR lo_repo IS NOT BOUND.
    RETURN.
  ENDIF.
  gv_switched = abap_false.
  DATA(lv_failed) = zcl_abapgit_mcp_branch=>restore( io_repo   = lo_repo
                                                     iv_branch = gv_prev_branch
                                                     iv_commit = gv_prev_commit ).
  IF lv_failed IS NOT INITIAL.
    " Everything goes into the message: an error message in START-OF-SELECTION
    " ends the report and discards the list, so a WRITE would never be seen.
    " The status bar shows about 73 characters, so the essential part comes
    " first: what failed and the branch it was on, then the error of the pull
    " (the restore error itself does not fit). Four fields of 50 characters:
    "   Branch restore failed: was <previous branch>; <original error>
    " or, when only the commit pin could not be set again:
    "   Pin restore failed: was <previous branch>; <original error>
    DATA(lv_f1) = COND string( WHEN lv_failed = zcl_abapgit_mcp_branch=>c_restore_failed-pin
                               THEN `Pin restore failed:`
                               ELSE `Branch restore failed:` ).
    DATA(lv_f2) = |was { gv_prev_branch };|.
    lv_f2 = substring( val = lv_f2 len = nmin( val1 = strlen( lv_f2 ) val2 = 50 ) ).
    DATA(lv_len) = strlen( iv_reason ).
    DATA(lv_cut) = nmin( val1 = lv_len val2 = 50 ).
    IF lv_len > 50.
      " cut at a blank, so that the join of the fields does not split a word
      DATA(lv_blank) = find( val = substring( val = iv_reason len = 50 ) sub = ` ` occ = -1 ).
      IF lv_blank >= 20.
        lv_cut = lv_blank + 1.
      ENDIF.
    ENDIF.
    DATA(lv_f3) = substring( val = iv_reason len = lv_cut ).
    DATA(lv_f4) = ``.
    IF lv_len > lv_cut.
      lv_f4 = substring( val = iv_reason off = lv_cut len = nmin( val1 = lv_len - lv_cut val2 = 50 ) ).
    ENDIF.
    MESSAGE e398(00) WITH lv_f1 lv_f2 lv_f3 lv_f4.
  ENDIF.
ENDFORM.
