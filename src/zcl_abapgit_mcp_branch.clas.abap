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

  PRIVATE SECTION.

    CONSTANTS c_heads TYPE string VALUE `refs/heads/`.

ENDCLASS.



CLASS zcl_abapgit_mcp_branch IMPLEMENTATION.


  METHOD normalise.

    rv_branch = condense( CONV string( iv_branch ) ).
    IF rv_branch IS INITIAL OR starts_with( val = rv_branch sub = c_heads ).
      RETURN.
    ENDIF.
    rv_branch = c_heads && rv_branch.

  ENDMETHOD.


  METHOD select.

    DATA(lv_branch) = normalise( iv_branch ).
    IF lv_branch IS INITIAL OR lv_branch = io_repo->get_selected_branch( ).
      rv_found = abap_true.
      RETURN.
    ENDIF.

    " An error of the remote request itself (host, credentials) is raised as it is.
    " Only a branch missing from a successfully fetched list means "unknown".
    DATA(li_branches) = zcl_abapgit_git_factory=>get_git_transport( )->branches( io_repo->get_url( ) ).
    TRY.
        li_branches->find_by_name( lv_branch ).
      CATCH zcx_abapgit_exception.
        rv_found = abap_false.
        RETURN.
    ENDTRY.

    io_repo->select_branch( lv_branch ).
    rv_found = abap_true.

  ENDMETHOD.
ENDCLASS.
