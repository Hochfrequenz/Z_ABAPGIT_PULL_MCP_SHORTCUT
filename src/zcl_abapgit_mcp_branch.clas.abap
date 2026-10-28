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
    "! A failing request for the branch list of the remote is raised.
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

    "! Same as SELECT, for any implementation of the seam
    CLASS-METHODS select_in
      IMPORTING
        ii_gateway      TYPE REF TO zif_abapgit_mcp_branch_gw
        iv_branch       TYPE csequence
      RETURNING
        VALUE(rv_found) TYPE abap_bool
      RAISING
        zcx_abapgit_exception.

  PRIVATE SECTION.

    CONSTANTS c_heads TYPE string VALUE `refs/heads/`.

ENDCLASS.



CLASS zcl_abapgit_mcp_branch IMPLEMENTATION.


  METHOD normalise.

    rv_branch = condense( CONV string( iv_branch ) ).
    IF rv_branch IS INITIAL OR contains( val = rv_branch start = c_heads ).
      RETURN.
    ENDIF.
    rv_branch = c_heads && rv_branch.

  ENDMETHOD.


  METHOD select.

    " Nothing to do, and no need to touch the repository, for an empty branch
    IF normalise( iv_branch ) IS INITIAL.
      rv_found = abap_true.
      RETURN.
    ENDIF.
    rv_found = select_in( ii_gateway = NEW lcl_abapgit_gateway( io_repo )
                          iv_branch  = iv_branch ).

  ENDMETHOD.


  METHOD select_in.

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
