CLASS ltcl_gateway_double DEFINITION FINAL FOR TESTING.

  PUBLIC SECTION.
    INTERFACES zif_abapgit_mcp_branch_gw.

    DATA mv_selected TYPE string.
    DATA mv_commit TYPE string.
    DATA mt_remote TYPE string_table.
    DATA mv_fail TYPE abap_bool.
    DATA mv_select_calls TYPE i.
    DATA mv_commit_calls TYPE i.
    DATA mv_fail_select TYPE abap_bool.
    DATA mv_fail_commit TYPE abap_bool.

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


  METHOD zif_abapgit_mcp_branch_gw~select_commit.
    IF mv_fail_commit = abap_true.
      zcx_abapgit_exception=>raise( `select commit failed` ).
    ENDIF.
    mv_commit_calls = mv_commit_calls + 1.
    mv_commit = iv_commit.
  ENDMETHOD.


  METHOD zif_abapgit_mcp_branch_gw~select_branch.
    IF mv_fail_select = abap_true.
      zcx_abapgit_exception=>raise( `select failed` ).
    ENDIF.
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
    METHODS other_refs_are_refused      FOR TESTING.
    METHODS head_is_refused             FOR TESTING.
    METHODS leading_slash_is_refused    FOR TESTING.
    METHODS bare_prefix_is_refused      FOR TESTING.
    METHODS valid_values_pass_check     FOR TESTING.
    METHODS semicolon_is_refused        FOR TESTING.
    METHODS blanks_inside_are_refused   FOR TESTING.
    METHODS invalid_branch_is_raised    FOR TESTING.
    METHODS restore_selects_previous    FOR TESTING RAISING zcx_abapgit_exception.
    METHODS restore_pins_commit_again   FOR TESTING RAISING zcx_abapgit_exception.
    METHODS restore_is_noop_when_equal  FOR TESTING RAISING zcx_abapgit_exception.
    METHODS restore_failure_is_flagged  FOR TESTING RAISING zcx_abapgit_exception.
    METHODS restore_without_branch      FOR TESTING RAISING zcx_abapgit_exception.
    METHODS restore_commit_fail_flagged FOR TESTING RAISING zcx_abapgit_exception.
    METHODS restore_same_branch_new_pin FOR TESTING RAISING zcx_abapgit_exception.
    METHODS pin_switch_fail_restores    FOR TESTING RAISING zcx_abapgit_exception.
    METHODS pin_switch_restore_fails    FOR TESTING RAISING zcx_abapgit_exception.
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


  METHOD other_refs_are_refused.
    cl_abap_unit_assert=>assert_not_initial( zcl_abapgit_mcp_branch=>check( `refs/tags/v1` ) ).
    cl_abap_unit_assert=>assert_not_initial( zcl_abapgit_mcp_branch=>check( `refs/remotes/origin/x` ) ).
    cl_abap_unit_assert=>assert_not_initial( zcl_abapgit_mcp_branch=>check( `refs/x` ) ).
  ENDMETHOD.


  METHOD head_is_refused.
    cl_abap_unit_assert=>assert_not_initial( zcl_abapgit_mcp_branch=>check( `HEAD` ) ).
    cl_abap_unit_assert=>assert_not_initial( zcl_abapgit_mcp_branch=>check( ` HEAD ` ) ).
  ENDMETHOD.


  METHOD leading_slash_is_refused.
    cl_abap_unit_assert=>assert_not_initial( zcl_abapgit_mcp_branch=>check( `/main` ) ).
    cl_abap_unit_assert=>assert_not_initial( zcl_abapgit_mcp_branch=>check( `/refs/heads/main` ) ).
  ENDMETHOD.


  METHOD bare_prefix_is_refused.
    cl_abap_unit_assert=>assert_not_initial( zcl_abapgit_mcp_branch=>check( `refs/heads/` ) ).
  ENDMETHOD.


  METHOD semicolon_is_refused.
    " The OK-code parameter parser of the report splits on ;
    cl_abap_unit_assert=>assert_not_initial( zcl_abapgit_mcp_branch=>check( `main;P_TRKORR=X` ) ).
    cl_abap_unit_assert=>assert_not_initial( zcl_abapgit_mcp_branch=>check( `a;b` ) ).
  ENDMETHOD.


  METHOD blanks_inside_are_refused.
    cl_abap_unit_assert=>assert_not_initial( zcl_abapgit_mcp_branch=>check( `my branch` ) ).
    cl_abap_unit_assert=>assert_not_initial( zcl_abapgit_mcp_branch=>check( |a{ cl_abap_char_utilities=>horizontal_tab }b| ) ).
  ENDMETHOD.


  METHOD valid_values_pass_check.
    " Empty and blanks mean: do not switch, which is not an error
    cl_abap_unit_assert=>assert_initial( zcl_abapgit_mcp_branch=>check( `` ) ).
    cl_abap_unit_assert=>assert_initial( zcl_abapgit_mcp_branch=>check( `   ` ) ).
    cl_abap_unit_assert=>assert_initial( zcl_abapgit_mcp_branch=>check( `main` ) ).
    cl_abap_unit_assert=>assert_initial( zcl_abapgit_mcp_branch=>check( `feature/x` ) ).
    cl_abap_unit_assert=>assert_initial( zcl_abapgit_mcp_branch=>check( `refs/heads/feature/x` ) ).
  ENDMETHOD.


  METHOD invalid_branch_is_raised.
    DATA lx_error TYPE REF TO zcx_abapgit_exception.
    DATA lv_found TYPE abap_bool.
    DATA(lo_double) = NEW ltcl_gateway_double( ).
    lo_double->mv_selected = `refs/heads/main`.
    lo_double->mt_remote = VALUE #( ( `refs/heads/main` ) ( `refs/heads/HEAD` ) ).

    TRY.
        lv_found = zcl_abapgit_mcp_branch=>select_in( ii_gateway = lo_double
                                                      iv_branch  = `HEAD` ).
      CATCH zcx_abapgit_exception INTO lx_error.
    ENDTRY.
    cl_abap_unit_assert=>assert_bound( lx_error ).
    cl_abap_unit_assert=>assert_equals( exp = 0 act = lo_double->mv_select_calls ).
  ENDMETHOD.


  METHOD restore_selects_previous.
    " The pull failed after the switch: the repository is put back on main
    DATA(lo_double) = NEW ltcl_gateway_double( ).
    lo_double->mv_selected = `refs/heads/feature/x`.

    cl_abap_unit_assert=>assert_initial( zcl_abapgit_mcp_branch=>restore_in( ii_gateway = lo_double
                                                                          iv_branch  = `refs/heads/main` ) ).
    cl_abap_unit_assert=>assert_equals( exp = `refs/heads/main` act = lo_double->mv_selected ).
    cl_abap_unit_assert=>assert_equals( exp = 0 act = lo_double->mv_commit_calls ).
  ENDMETHOD.


  METHOD restore_pins_commit_again.
    " A pin is cleared by the switch and must come back
    DATA(lc_commit) = `0123456789abcdef0123456789abcdef01234567`.
    DATA(lo_double) = NEW ltcl_gateway_double( ).
    lo_double->mv_selected = `refs/heads/feature/x`.

    cl_abap_unit_assert=>assert_initial( zcl_abapgit_mcp_branch=>restore_in( ii_gateway = lo_double
                                                                          iv_branch  = `refs/heads/main`
                                                                          iv_commit  = lc_commit ) ).
    cl_abap_unit_assert=>assert_equals( exp = `refs/heads/main` act = lo_double->mv_selected ).
    cl_abap_unit_assert=>assert_equals( exp = lc_commit act = lo_double->mv_commit ).
  ENDMETHOD.


  METHOD restore_is_noop_when_equal.
    DATA(lo_double) = NEW ltcl_gateway_double( ).
    lo_double->mv_selected = `refs/heads/main`.

    cl_abap_unit_assert=>assert_initial( zcl_abapgit_mcp_branch=>restore_in( ii_gateway = lo_double
                                                                          iv_branch  = `refs/heads/main` ) ).
    cl_abap_unit_assert=>assert_equals( exp = 0 act = lo_double->mv_select_calls ).
    cl_abap_unit_assert=>assert_equals( exp = 0 act = lo_double->mv_commit_calls ).
  ENDMETHOD.


  METHOD restore_failure_is_flagged.
    " Never raises: the caller reports its own error
    DATA(lo_double) = NEW ltcl_gateway_double( ).
    lo_double->mv_selected = `refs/heads/feature/x`.
    lo_double->mv_fail_select = abap_true.

    cl_abap_unit_assert=>assert_equals( exp = zcl_abapgit_mcp_branch=>c_restore_failed-branch
                                        act = zcl_abapgit_mcp_branch=>restore_in( ii_gateway = lo_double
                                                                                  iv_branch  = `refs/heads/main` ) ).
  ENDMETHOD.


  METHOD restore_without_branch.
    " Nothing remembered, nothing to restore
    DATA(lo_double) = NEW ltcl_gateway_double( ).
    lo_double->mv_selected = `refs/heads/feature/x`.

    cl_abap_unit_assert=>assert_initial( zcl_abapgit_mcp_branch=>restore_in( ii_gateway = lo_double
                                                                          iv_branch  = `` ) ).
    cl_abap_unit_assert=>assert_equals( exp = 0 act = lo_double->mv_select_calls ).
  ENDMETHOD.

  METHOD restore_commit_fail_flagged.
    " select_commit fails after select_branch worked: flagged, never raised
    DATA(lo_double) = NEW ltcl_gateway_double( ).
    lo_double->mv_selected = `refs/heads/feature/x`.
    lo_double->mv_fail_commit = abap_true.

    " The branch is back, only the pin is not: told apart from a failed branch restore
    cl_abap_unit_assert=>assert_equals(
      exp = zcl_abapgit_mcp_branch=>c_restore_failed-pin
      act = zcl_abapgit_mcp_branch=>restore_in( ii_gateway = lo_double
                                                iv_branch  = `refs/heads/main`
                                                iv_commit  = `0123456789abcdef0123456789abcdef01234567` ) ).
    cl_abap_unit_assert=>assert_equals( exp = `refs/heads/main` act = lo_double->mv_selected ).
    cl_abap_unit_assert=>assert_equals( exp = 0 act = lo_double->mv_commit_calls ).
  ENDMETHOD.


  METHOD restore_same_branch_new_pin.
    " The branch matches, the commit differs: not a no-op, the pin is restored
    DATA(lc_commit) = `0123456789abcdef0123456789abcdef01234567`.
    DATA(lo_double) = NEW ltcl_gateway_double( ).
    lo_double->mv_selected = `refs/heads/main`.

    cl_abap_unit_assert=>assert_initial( zcl_abapgit_mcp_branch=>restore_in( ii_gateway = lo_double
                                                                          iv_branch  = `refs/heads/main`
                                                                          iv_commit  = lc_commit ) ).
    cl_abap_unit_assert=>assert_equals( exp = lc_commit act = lo_double->mv_commit ).
    cl_abap_unit_assert=>assert_equals( exp = 1 act = lo_double->mv_commit_calls ).
  ENDMETHOD.

  METHOD pin_switch_fail_restores.
    " Case 9 of the report: pinned to a commit on main, switch to dev, the pull
    " fails afterwards, the report restores branch and pin as it remembered them.
    DATA(lc_commit) = `0123456789abcdef0123456789abcdef01234567`.
    DATA(lo_double) = NEW ltcl_gateway_double( ).
    lo_double->mv_selected = `refs/heads/main`.
    lo_double->mv_commit = lc_commit.
    lo_double->mt_remote = VALUE #( ( `refs/heads/main` ) ( `refs/heads/dev` ) ).
    DATA(lv_prev_branch) = lo_double->zif_abapgit_mcp_branch_gw~selected_branch( ).
    DATA(lv_prev_commit) = lo_double->zif_abapgit_mcp_branch_gw~selected_commit( ).

    cl_abap_unit_assert=>assert_true( zcl_abapgit_mcp_branch=>select_in( ii_gateway = lo_double
                                                                         iv_branch  = `dev` ) ).
    cl_abap_unit_assert=>assert_equals( exp = `refs/heads/dev` act = lo_double->mv_selected ).
    cl_abap_unit_assert=>assert_initial( lo_double->mv_commit ).

    cl_abap_unit_assert=>assert_initial( zcl_abapgit_mcp_branch=>restore_in( ii_gateway = lo_double
                                                                          iv_branch  = lv_prev_branch
                                                                          iv_commit  = lv_prev_commit ) ).
    cl_abap_unit_assert=>assert_equals( exp = `refs/heads/main` act = lo_double->mv_selected ).
    cl_abap_unit_assert=>assert_equals( exp = lc_commit act = lo_double->mv_commit ).
  ENDMETHOD.


  METHOD pin_switch_restore_fails.
    " Same, but the restore fails: flagged (the report then says so in its
    " message), the repository stays on the new branch, nothing is raised.
    DATA(lc_commit) = `0123456789abcdef0123456789abcdef01234567`.
    DATA(lo_double) = NEW ltcl_gateway_double( ).
    lo_double->mv_selected = `refs/heads/main`.
    lo_double->mv_commit = lc_commit.
    lo_double->mt_remote = VALUE #( ( `refs/heads/main` ) ( `refs/heads/dev` ) ).

    cl_abap_unit_assert=>assert_true( zcl_abapgit_mcp_branch=>select_in( ii_gateway = lo_double
                                                                         iv_branch  = `dev` ) ).
    lo_double->mv_fail_select = abap_true.
    cl_abap_unit_assert=>assert_equals( exp = zcl_abapgit_mcp_branch=>c_restore_failed-branch
                                        act = zcl_abapgit_mcp_branch=>restore_in( ii_gateway = lo_double
                                                                                  iv_branch  = `refs/heads/main`
                                                                                  iv_commit  = lc_commit ) ).
    cl_abap_unit_assert=>assert_equals( exp = `refs/heads/dev` act = lo_double->mv_selected ).
  ENDMETHOD.

ENDCLASS.
