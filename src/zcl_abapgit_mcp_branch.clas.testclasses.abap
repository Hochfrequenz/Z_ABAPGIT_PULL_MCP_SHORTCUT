CLASS ltcl_gateway_double DEFINITION FINAL FOR TESTING.

  PUBLIC SECTION.
    INTERFACES zif_abapgit_mcp_branch_gw.

    DATA mv_selected TYPE string.
    DATA mv_commit TYPE string.
    DATA mt_remote TYPE string_table.
    DATA mv_fail TYPE abap_bool.
    DATA mv_select_calls TYPE i.

ENDCLASS.


CLASS ltcl_gateway_double IMPLEMENTATION.

  METHOD zif_abapgit_mcp_branch_gw~selected_branch.
    rv_branch = mv_selected.
  ENDMETHOD.


  METHOD zif_abapgit_mcp_branch_gw~selected_commit.
    rv_commit = mv_commit.
  ENDMETHOD.


  METHOD zif_abapgit_mcp_branch_gw~remote_branches.
    IF mv_fail = abap_true.
      zcx_abapgit_exception=>raise( `remote unreachable` ).
    ENDIF.
    rt_branches = mt_remote.
  ENDMETHOD.


  METHOD zif_abapgit_mcp_branch_gw~select_branch.
    mv_select_calls = mv_select_calls + 1.
    mv_selected = iv_branch.
    CLEAR mv_commit.
  ENDMETHOD.

ENDCLASS.


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
    METHODS unknown_branch_not_selected FOR TESTING RAISING zcx_abapgit_exception.
    METHODS known_branch_is_selected    FOR TESTING RAISING zcx_abapgit_exception.
    METHODS selected_branch_is_noop     FOR TESTING RAISING zcx_abapgit_exception.
    METHODS pinned_branch_is_reselected FOR TESTING RAISING zcx_abapgit_exception.
    METHODS remote_error_is_passed_on   FOR TESTING.
    METHODS bare_name_is_matched        FOR TESTING RAISING zcx_abapgit_exception.
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


  METHOD unknown_branch_not_selected.
    DATA(lo_double) = NEW ltcl_gateway_double( ).
    lo_double->mv_selected = `refs/heads/main`.
    lo_double->mt_remote = VALUE #( ( `refs/heads/main` ) ).

    cl_abap_unit_assert=>assert_false( zcl_abapgit_mcp_branch=>select_in( ii_gateway = lo_double
                                                                          iv_branch  = `nope` ) ).
    cl_abap_unit_assert=>assert_equals( exp = 0 act = lo_double->mv_select_calls ).
    cl_abap_unit_assert=>assert_equals( exp = `refs/heads/main` act = lo_double->mv_selected ).
  ENDMETHOD.


  METHOD known_branch_is_selected.
    DATA(lo_double) = NEW ltcl_gateway_double( ).
    lo_double->mv_selected = `refs/heads/main`.
    lo_double->mt_remote = VALUE #( ( `refs/heads/main` ) ( `refs/heads/feature/x` ) ).

    cl_abap_unit_assert=>assert_true( zcl_abapgit_mcp_branch=>select_in( ii_gateway = lo_double
                                                                         iv_branch  = `refs/heads/feature/x` ) ).
    cl_abap_unit_assert=>assert_equals( exp = 1 act = lo_double->mv_select_calls ).
    cl_abap_unit_assert=>assert_equals( exp = `refs/heads/feature/x` act = lo_double->mv_selected ).
  ENDMETHOD.


  METHOD bare_name_is_matched.
    DATA(lo_double) = NEW ltcl_gateway_double( ).
    lo_double->mv_selected = `refs/heads/main`.
    lo_double->mt_remote = VALUE #( ( `refs/heads/main` ) ( `refs/heads/dev` ) ).

    cl_abap_unit_assert=>assert_true( zcl_abapgit_mcp_branch=>select_in( ii_gateway = lo_double
                                                                         iv_branch  = `dev` ) ).
    cl_abap_unit_assert=>assert_equals( exp = `refs/heads/dev` act = lo_double->mv_selected ).
  ENDMETHOD.


  METHOD selected_branch_is_noop.
    " Not even the remote is asked: it is unreachable here
    DATA(lo_double) = NEW ltcl_gateway_double( ).
    lo_double->mv_selected = `refs/heads/main`.
    lo_double->mv_fail = abap_true.

    cl_abap_unit_assert=>assert_true( zcl_abapgit_mcp_branch=>select_in( ii_gateway = lo_double
                                                                         iv_branch  = `main` ) ).
    cl_abap_unit_assert=>assert_equals( exp = 0 act = lo_double->mv_select_calls ).
  ENDMETHOD.


  METHOD pinned_branch_is_reselected.
    DATA(lo_double) = NEW ltcl_gateway_double( ).
    lo_double->mv_selected = `refs/heads/main`.
    lo_double->mv_commit = `0123456789abcdef0123456789abcdef01234567`.
    lo_double->mt_remote = VALUE #( ( `refs/heads/main` ) ).

    cl_abap_unit_assert=>assert_true( zcl_abapgit_mcp_branch=>select_in( ii_gateway = lo_double
                                                                         iv_branch  = `main` ) ).
    cl_abap_unit_assert=>assert_equals( exp = 1 act = lo_double->mv_select_calls ).
    cl_abap_unit_assert=>assert_initial( lo_double->mv_commit ).
  ENDMETHOD.


  METHOD remote_error_is_passed_on.
    DATA lx_error TYPE REF TO zcx_abapgit_exception.
    DATA lv_found TYPE abap_bool.
    DATA(lo_double) = NEW ltcl_gateway_double( ).
    lo_double->mv_selected = `refs/heads/main`.
    lo_double->mv_fail = abap_true.

    TRY.
        lv_found = zcl_abapgit_mcp_branch=>select_in( ii_gateway = lo_double
                                                      iv_branch  = `dev` ).
      CATCH zcx_abapgit_exception INTO lx_error.
    ENDTRY.
    cl_abap_unit_assert=>assert_bound( lx_error ).
    cl_abap_unit_assert=>assert_equals( exp = 0 act = lo_double->mv_select_calls ).
  ENDMETHOD.

ENDCLASS.
