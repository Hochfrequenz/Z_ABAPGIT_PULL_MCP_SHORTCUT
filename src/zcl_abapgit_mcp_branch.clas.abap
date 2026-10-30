"! <p class="shorttext synchronized">abapGit sync: select the branch of an online repository</p>
"! Shared by the report Z_ABAPGIT_PULL_MCP_SHORTCUT and the ADT endpoints.
"! Like ZCL_ABAPGIT_MCP_REPO_MATCH it is kept apart from ZCL_ABAPGIT_MCP_SYNC,
"! so that the report depends on as few abapGit APIs as possible.
CLASS zcl_abapgit_mcp_branch DEFINITION
  PUBLIC
  FINAL
  CREATE PUBLIC.

  PUBLIC SECTION.

    "! Full name of a branch: a bare name gets the prefix refs/heads/, a name that
    "! already starts with it stays as it is. Surrounding blanks are dropped.
    "! Empty stays empty, which means: do not switch.
    CLASS-METHODS normalise
      IMPORTING
        iv_branch        TYPE csequence
      RETURNING
        VALUE(rv_branch) TYPE string.

    "! Selects the branch of the repository, persistently like the branch switch
    "! of the abapGit UI. Does nothing for an empty branch and for the branch
    "! that is selected already. A branch that does not exist on the remote is
    "! reported by abap_false and leaves the selected branch unchanged;
    "! abapGit's own select_branch does not check that.
    "! A failing request for the branch list of the remote is raised, and so is a
    "! value that CHECK refuses.
    "! @parameter io_repo | online repository
    "! @parameter iv_branch | bare or full branch name
    "! @parameter rv_found | abap_true: the repository is on the branch afterwards
    CLASS-METHODS select
      IMPORTING
        io_repo         TYPE REF TO zcl_abapgit_repo_online
        iv_branch       TYPE csequence
      RETURNING
        VALUE(rv_found) TYPE abap_bool
      RAISING
        zcx_abapgit_exception.

    "! Reason why a branch value is refused, empty when it is fine (an empty value
    "! is fine: it means do not switch). Refused: HEAD, a leading slash, refs/ values
    "! other than refs/heads/, refs/heads/ without a name, and blanks or semicolons
    "! (the OK-code parameter parser of the report splits on them).
    CLASS-METHODS check
      IMPORTING
        iv_branch       TYPE csequence
      RETURNING
        VALUE(rv_error) TYPE string.

    "! Puts a repository back on a branch and commit remembered before SELECT.
    "! Does nothing when it is there already. Never raises, so it cannot hide the
    "! error that made the caller restore. Empty result: restored. c_restore_failed-branch:
    "! the branch could not be selected. c_restore_failed-pin: the branch is back, but
    "! pinning the commit again failed.
    "! @parameter io_repo | online repository
    "! @parameter iv_branch | full branch name from before the switch
    "! @parameter iv_commit | commit pin from before the switch, initial if none
    CLASS-METHODS restore
      IMPORTING
        io_repo          TYPE REF TO zcl_abapgit_repo_online
        iv_branch        TYPE csequence
        iv_commit        TYPE csequence OPTIONAL
      RETURNING
        VALUE(rv_failed) TYPE string.

    "! Same as RESTORE, for any implementation of the seam
    CLASS-METHODS restore_in
      IMPORTING
        ii_gateway       TYPE REF TO zif_abapgit_mcp_branch_gw
        iv_branch        TYPE csequence
        iv_commit        TYPE csequence OPTIONAL
      RETURNING
        VALUE(rv_failed) TYPE string.

    "! Same as SELECT, for any implementation of the seam
    CLASS-METHODS select_in
      IMPORTING
        ii_gateway      TYPE REF TO zif_abapgit_mcp_branch_gw
        iv_branch       TYPE csequence
      RETURNING
        VALUE(rv_found) TYPE abap_bool
      RAISING
        zcx_abapgit_exception.

    CONSTANTS:
      BEGIN OF c_restore_failed,
        branch TYPE string VALUE `BRANCH`,
        pin    TYPE string VALUE `PIN`,
      END OF c_restore_failed.

  PRIVATE SECTION.

    CONSTANTS c_heads TYPE string VALUE `refs/heads/`.
    CONSTANTS c_refs TYPE string VALUE `refs/`.

ENDCLASS.



CLASS zcl_abapgit_mcp_branch IMPLEMENTATION.


  METHOD normalise.

    rv_branch = condense( CONV string( iv_branch ) ).
    IF rv_branch IS INITIAL OR contains( val = rv_branch start = c_heads ).
      RETURN.
    ENDIF.
    rv_branch = c_heads && rv_branch.

  ENDMETHOD.


  METHOD check.

    DATA(lv_branch) = condense( CONV string( iv_branch ) ).
    IF lv_branch IS INITIAL.
      RETURN.
    ENDIF.
    IF contains( val = lv_branch regex = `[\s;]` ).
      rv_error = `Invalid branch: must not contain blanks or semicolons`.
    ELSEIF lv_branch = `HEAD`.
      rv_error = `Invalid branch: HEAD is not a branch name`.
    ELSEIF lv_branch(1) = `/`.
      rv_error = `Invalid branch: must not start with /`.
    ELSEIF lv_branch = c_heads.
      rv_error = `Invalid branch: name after refs/heads/ is missing`.
    ELSEIF contains( val = lv_branch start = c_refs )
        AND NOT contains( val = lv_branch start = c_heads ).
      rv_error = `Invalid branch: only refs/heads/ is allowed`.
    ENDIF.

  ENDMETHOD.


  METHOD restore.

    rv_failed = restore_in( ii_gateway = NEW lcl_abapgit_gateway( io_repo )
                            iv_branch  = iv_branch
                            iv_commit  = iv_commit ).

  ENDMETHOD.


  METHOD restore_in.

    IF iv_branch IS INITIAL.
      RETURN.
    ENDIF.
    DATA(lv_stage) = c_restore_failed-branch.
    TRY.
        IF ii_gateway->selected_branch( ) = iv_branch
           AND ii_gateway->selected_commit( ) = iv_commit.
          RETURN.
        ENDIF.
        " select_branch clears a pin, so the commit is pinned again afterwards
        ii_gateway->select_branch( CONV #( iv_branch ) ).
        IF iv_commit IS NOT INITIAL.
          lv_stage = c_restore_failed-pin.
          ii_gateway->select_commit( CONV #( iv_commit ) ).
        ENDIF.
      CATCH zcx_abapgit_exception.
        rv_failed = lv_stage.
    ENDTRY.

  ENDMETHOD.


  METHOD select.

    DATA(lv_error) = check( iv_branch ).
    IF lv_error IS NOT INITIAL.
      zcx_abapgit_exception=>raise( lv_error ).
    ENDIF.
    " Nothing to do, and no need to touch the repository, for an empty branch
    IF normalise( iv_branch ) IS INITIAL.
      rv_found = abap_true.
      RETURN.
    ENDIF.
    rv_found = select_in( ii_gateway = NEW lcl_abapgit_gateway( io_repo )
                          iv_branch  = iv_branch ).

  ENDMETHOD.


  METHOD select_in.

    DATA(lv_error) = check( iv_branch ).
    IF lv_error IS NOT INITIAL.
      zcx_abapgit_exception=>raise( lv_error ).
    ENDIF.
    DATA(lv_branch) = normalise( iv_branch ).
    IF lv_branch IS INITIAL.
      rv_found = abap_true.
      RETURN.
    ENDIF.
    " Same branch is a no-op only when the repository follows it. A pin to a commit
    " would survive and the pull would deserialize the pinned commit, so select the
    " branch again: select_branch clears the pin.
    IF lv_branch = ii_gateway->selected_branch( ) AND ii_gateway->selected_commit( ) IS INITIAL.
      rv_found = abap_true.
      RETURN.
    ENDIF.

    " An error of the remote request itself (host, credentials) is raised as it is.
    " Only a branch missing from a successfully fetched list means "unknown".
    DATA(lt_remote) = ii_gateway->remote_branches( ).
    IF NOT line_exists( lt_remote[ table_line = lv_branch ] ).
      rv_found = abap_false.
      RETURN.
    ENDIF.

    ii_gateway->select_branch( lv_branch ).
    rv_found = abap_true.

  ENDMETHOD.
ENDCLASS.
