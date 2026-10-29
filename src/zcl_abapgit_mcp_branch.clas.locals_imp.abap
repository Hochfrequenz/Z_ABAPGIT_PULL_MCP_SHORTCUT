"! Default seam: an online repository and its Git remote
CLASS lcl_abapgit_gateway DEFINITION FINAL.

  PUBLIC SECTION.
    INTERFACES zif_abapgit_mcp_branch_gw.

    METHODS constructor
      IMPORTING
        io_repo TYPE REF TO zcl_abapgit_repo_online.

  PRIVATE SECTION.
    DATA mo_repo TYPE REF TO zcl_abapgit_repo_online.

ENDCLASS.


CLASS lcl_abapgit_gateway IMPLEMENTATION.

  METHOD constructor.
    mo_repo = io_repo.
  ENDMETHOD.


  METHOD zif_abapgit_mcp_branch_gw~selected_branch.
    rv_branch = mo_repo->get_selected_branch( ).
  ENDMETHOD.


  METHOD zif_abapgit_mcp_branch_gw~selected_commit.
    rv_commit = mo_repo->get_selected_commit( ).
  ENDMETHOD.


  METHOD zif_abapgit_mcp_branch_gw~remote_branches.
    " Static method of the transport class: exists in old and new abapGit versions
    DATA(lo_list) = zcl_abapgit_git_transport=>branches( mo_repo->get_url( ) ).
    LOOP AT lo_list->get_branches_only( ) INTO DATA(ls_branch).
      APPEND ls_branch-name TO rt_branches.
    ENDLOOP.
  ENDMETHOD.


  METHOD zif_abapgit_mcp_branch_gw~select_branch.
    mo_repo->select_branch( iv_branch ).
  ENDMETHOD.


  METHOD zif_abapgit_mcp_branch_gw~select_commit.
    " abapGit types the parameter as a 40 character SHA-1 (C(40)), not as a string
    mo_repo->select_commit( CONV #( iv_commit ) ).
  ENDMETHOD.

ENDCLASS.
