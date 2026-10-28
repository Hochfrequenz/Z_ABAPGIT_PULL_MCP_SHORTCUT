CLASS ltcl_branch DEFINITION FINAL FOR TESTING
  DURATION SHORT
  RISK LEVEL HARMLESS.

  PRIVATE SECTION.
    METHODS bare_name_gets_prefix      FOR TESTING.
    METHODS full_name_is_unchanged     FOR TESTING.
    METHODS empty_means_no_switch      FOR TESTING.
    METHODS blanks_are_dropped         FOR TESTING.
    METHODS slash_in_name_is_kept      FOR TESTING.
    METHODS empty_branch_selects_nothing FOR TESTING RAISING zcx_abapgit_exception.
ENDCLASS.


CLASS ltcl_branch IMPLEMENTATION.

  METHOD bare_name_gets_prefix.
    cl_abap_unit_assert=>assert_equals( exp = `refs/heads/main`
                                        act = zcl_abapgit_mcp_branch=>normalise( `main` ) ).
  ENDMETHOD.


  METHOD full_name_is_unchanged.
    cl_abap_unit_assert=>assert_equals( exp = `refs/heads/x`
                                        act = zcl_abapgit_mcp_branch=>normalise( `refs/heads/x` ) ).
  ENDMETHOD.


  METHOD empty_means_no_switch.
    cl_abap_unit_assert=>assert_initial( zcl_abapgit_mcp_branch=>normalise( `` ) ).
    cl_abap_unit_assert=>assert_initial( zcl_abapgit_mcp_branch=>normalise( `   ` ) ).
  ENDMETHOD.


  METHOD blanks_are_dropped.
    cl_abap_unit_assert=>assert_equals( exp = `refs/heads/main`
                                        act = zcl_abapgit_mcp_branch=>normalise( ` main ` ) ).
  ENDMETHOD.


  METHOD slash_in_name_is_kept.
    " Branch names like feature/x are common; only the refs/heads/ prefix counts
    cl_abap_unit_assert=>assert_equals( exp = `refs/heads/feature/x`
                                        act = zcl_abapgit_mcp_branch=>normalise( `feature/x` ) ).
  ENDMETHOD.


  METHOD empty_branch_selects_nothing.
    " No repository needed: an empty branch returns before it is touched
    cl_abap_unit_assert=>assert_true(
      zcl_abapgit_mcp_branch=>select( io_repo   = VALUE #( )
                                      iv_branch = `` ) ).
  ENDMETHOD.

ENDCLASS.
