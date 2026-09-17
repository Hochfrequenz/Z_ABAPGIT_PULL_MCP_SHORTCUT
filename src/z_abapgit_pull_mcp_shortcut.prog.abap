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
    p_repo   TYPE string LOWER CASE,           " Repository name (required for PULL)
    p_trkorr TYPE trkorr.                       " Transport request (F4 available)
SELECTION-SCREEN END OF BLOCK b1.

SELECTION-SCREEN BEGIN OF BLOCK b2 WITH FRAME TITLE TEXT-002.
  PARAMETERS:
    p_user  TYPE string LOWER CASE,             " GitHub username
    p_token TYPE string LOWER CASE.              " GitHub PAT (Personal Access Token)
SELECTION-SCREEN END OF BLOCK b2.

INITIALIZATION.
  gc_hint = 'Valid actions: PULL (pull repo) | LIST (list all repos)'.

AT SELECTION-SCREEN.
  IF p_action <> 'PULL' AND p_action <> 'LIST'.
    MESSAGE e398(00) WITH 'Invalid P_ACTION:' p_action '. Use PULL or LIST.' ''.
  ENDIF.

CLASS lcl_util DEFINITION.
  PUBLIC SECTION.
    " Uppercase, and drop a trailing slash and a .git suffix, so the same
    " repository written three legitimate ways still matches. abapGit
    " itself compares URLs case-insensitively rather than literally.
    CLASS-METHODS normalise
      IMPORTING iv_url        TYPE string
      RETURNING VALUE(rv_url) TYPE string.
ENDCLASS.

CLASS lcl_util IMPLEMENTATION.
  METHOD normalise.
    rv_url = to_upper( iv_url ).
    IF rv_url CP '*/'.
      rv_url = substring( val = rv_url len = strlen( rv_url ) - 1 ).
    ENDIF.
    IF rv_url CP '*.GIT'.
      rv_url = substring( val = rv_url len = strlen( rv_url ) - 4 ).
    ENDIF.
  ENDMETHOD.
ENDCLASS.

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
        " Padded to seven fields so it is NOT a breaking change: a
        " consumer that splits every line into seven still gets seven,
        " and one that looks for a header still finds TOTAL in field 1.
        " The five trailing tildes are cheaper than a deployment order
        " constraint between this report and its reader.
        DATA(lt_repos) = zcl_abapgit_repo_srv=>get_instance( )->list( ).
        WRITE: / |TOTAL~{ lines( lt_repos ) }~~~~~|.

        LOOP AT lt_repos INTO DATA(li_repo_list).
          DATA(lv_offline) = li_repo_list->is_offline( ).
          DATA(lv_offline_flag) = COND string( WHEN lv_offline = abap_true THEN 'X' ELSE '' ).
          DATA(lv_url) = COND string( WHEN lv_offline = abap_false
                                      THEN CAST zcl_abapgit_repo_online( li_repo_list )->get_url( )
                                      ELSE '' ).
          DATA(lv_ts) = COND string( WHEN li_repo_list->ms_data-deserialized_at IS NOT INITIAL
                                     THEN |{ li_repo_list->ms_data-deserialized_at }|
                                     ELSE '' ).
          DATA(lv_line) = li_repo_list->get_name( ) && '~' &&
                          lv_url && '~' &&
                          li_repo_list->get_package( ) && '~' &&
                          li_repo_list->ms_data-branch_name && '~' &&
                          lv_ts && '~' &&
                          li_repo_list->ms_data-deserialized_by && '~' &&
                          lv_offline_flag.
          WRITE: / lv_line.
        ENDLOOP.

      CATCH cx_root INTO DATA(lx_list_error).
        MESSAGE e398(00) WITH lx_list_error->get_text( ) '' '' ''.
    ENDTRY.
    RETURN.
  ENDIF.

* --- PULL mode (existing logic, unchanged) ---
  IF p_repo IS INITIAL.
    MESSAGE e398(00) WITH 'P_REPO is required for PULL action' '' '' ''.
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
      DATA lt_hits TYPE STANDARD TABLE OF REF TO zcl_abapgit_repo_online WITH EMPTY KEY.

      DATA lo_online TYPE REF TO zcl_abapgit_repo_online.

      " Two different comparands on purpose. The URL is normalised (a
      " trailing slash and a .git suffix are noise there); the name is
      " only uppercased, because for a NAME those characters are real.
      DATA(lv_want)      = lcl_util=>normalise( p_repo ).
      DATA(lv_want_name) = to_upper( p_repo ).

      LOOP AT zcl_abapgit_repo_srv=>get_instance( )->list( iv_offline = abap_false ) INTO DATA(li_repo).
        " Defensive: list( iv_offline = abap_false ) should yield only
        " online repos, but this code is the last thing between the
        " caller and an auto-confirmed overwrite, so it does not assume.
        " An unguarded CAST here would abort the whole search on one bad
        " entry and make a matchable repo later in the list unreachable.
        CLEAR lo_online.
        TRY.
            lo_online ?= li_repo.
          CATCH cx_sy_move_cast_error.
            CONTINUE.
        ENDTRY.

        " URL as well as name: a URL is genuinely unique, whereas
        " get_name( ) falls back to a URL-derived value when the stored
        " name is blank. Case-insensitive on both, because the old CS
        " match was too - dropping that would be an unannounced
        " regression for every caller passing a differently-cased name,
        " and exactness is orthogonal to case now that an ambiguous
        " P_REPO is an explicit error.
        IF to_upper( lo_online->get_name( ) ) = lv_want_name
           OR lcl_util=>normalise( lo_online->get_url( ) ) = lv_want.
          APPEND lo_online TO lt_hits.
        ENDIF.
      ENDLOOP.

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

      IF p_user IS NOT INITIAL AND p_token IS NOT INITIAL.
        zcl_abapgit_login_manager=>set(
          iv_uri      = lo_repo->get_url( )
          iv_username = p_user
          iv_password = p_token ).
      ENDIF.

      DATA(ls_checks) = lo_repo->deserialize_checks( ).

      IF ls_checks-transport-required = abap_true AND p_trkorr IS INITIAL.
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
          MESSAGE e398(00) WITH 'Pull log:' lv_msg '' ''.
        ELSE.
          MESSAGE e398(00) WITH 'Pull failed: deserialization log has issues' '' '' ''.
        ENDIF.
        RETURN.
      ENDIF.

      MESSAGE s398(00) WITH 'Pull successful:' lo_repo->get_name( ) '' ''.

    CATCH cx_root INTO DATA(lx_error).
      MESSAGE e398(00) WITH lx_error->get_text( ) '' '' ''.
  ENDTRY.
