CLASS ltcl_pull_rule DEFINITION FINAL FOR TESTING
  DURATION SHORT
  RISK LEVEL HARMLESS.

  PRIVATE SECTION.
    CONSTANTS c_class TYPE string VALUE `CLAS`.
    CONSTANTS c_name  TYPE string VALUE `ZCL_EXAMPLE`.

    METHODS overwrite_entry
      IMPORTING
        iv_action       TYPE string
      RETURNING
        VALUE(rs_entry) TYPE zcl_abapgit_mcp_guard=>ty_decision_entry.

    METHODS make_file
      IMPORTING
        iv_filename    TYPE string DEFAULT `zcl_example.clas.abap`
        iv_lstate      TYPE string
        iv_rstate      TYPE string
      RETURNING
        VALUE(rs_file) TYPE zcl_abapgit_mcp_guard=>ty_file.

    METHODS required_count
      IMPORTING
        is_entry        TYPE zcl_abapgit_mcp_guard=>ty_decision_entry
        it_files        TYPE zcl_abapgit_mcp_guard=>ty_files
        it_confirm      TYPE zif_abapgit_mcp_sync=>ty_confirmations OPTIONAL
      RETURNING
        VALUE(rv_count) TYPE i.

    METHODS git_only_changes_auto_confirm   FOR TESTING.
    METHODS every_local_state_needs_conf FOR TESTING.
    METHODS collapsed_md_and_d_needs_conf   FOR TESTING.
    METHODS overwrite_action_needs_confirm  FOR TESTING.
    METHODS packmove_needs_confirm          FOR TESTING.
    METHODS no_support_needs_confirm        FOR TESTING.
    METHODS warning_package_needs_confirm   FOR TESTING.
    METHODS unknown_table_needs_confirm     FOR TESTING.
    METHODS object_without_files_fails_cl   FOR TESTING.
    METHODS matching_confirmation_covers    FOR TESTING.
    METHODS stale_action_does_not_cover     FOR TESTING.
    METHODS required_entry_lists_files      FOR TESTING.
ENDCLASS.


CLASS ltcl_pull_rule IMPLEMENTATION.

  METHOD overwrite_entry.
    rs_entry = VALUE #( table    = zcl_abapgit_mcp_guard=>c_table-overwrite
                        obj_type = c_class
                        obj_name = c_name
                        action   = iv_action
                        text     = `text` ).
  ENDMETHOD.


  METHOD make_file.
    rs_file = VALUE #( obj_type = c_class
                       obj_name = c_name
                       path     = `/src/`
                       filename = iv_filename
                       lstate   = iv_lstate
                       rstate   = iv_rstate ).
  ENDMETHOD.


  METHOD required_count.
    rv_count = lines( zcl_abapgit_mcp_guard=>unconfirmed_pull_entries(
                        it_entries = VALUE #( ( is_entry ) )
                        it_files   = it_files
                        it_confirm = it_confirm ) ).
  ENDMETHOD.


  METHOD git_only_changes_auto_confirm.
    DATA(lt_rstates) = VALUE string_table( ( `` ) ( `A` ) ( `M` ) ( `D` ) ).
    DATA(lt_actions) = VALUE string_table( ( zif_abapgit_mcp_sync=>c_action-add )
                                           ( zif_abapgit_mcp_sync=>c_action-update )
                                           ( zif_abapgit_mcp_sync=>c_action-delete ) ).

    LOOP AT lt_actions INTO DATA(lv_action).
      LOOP AT lt_rstates INTO DATA(lv_rstate).
        cl_abap_unit_assert=>assert_equals(
          exp = 0
          act = required_count( is_entry = overwrite_entry( lv_action )
                                it_files = VALUE #( ( make_file( iv_lstate = `` iv_rstate = lv_rstate ) ) ) )
          msg = |action { lv_action } with state _{ lv_rstate } must be auto-confirmed| ).
      ENDLOOP.
    ENDLOOP.
  ENDMETHOD.


  METHOD every_local_state_needs_conf.
    " All two-character states with a local part: A_ AA AM AD M_ MA MM MD D_ DA DM DD
    DATA(lt_lstates) = VALUE string_table( ( `A` ) ( `M` ) ( `D` ) ).
    DATA(lt_rstates) = VALUE string_table( ( `` ) ( `A` ) ( `M` ) ( `D` ) ).

    LOOP AT lt_lstates INTO DATA(lv_lstate).
      LOOP AT lt_rstates INTO DATA(lv_rstate).
        cl_abap_unit_assert=>assert_equals(
          exp = 1
          act = required_count( is_entry = overwrite_entry( zif_abapgit_mcp_sync=>c_action-update )
                                it_files = VALUE #( ( make_file( iv_lstate = lv_lstate iv_rstate = lv_rstate ) ) ) )
          msg = |state { lv_lstate }{ lv_rstate } must need a confirmation| ).
      ENDLOOP.
    ENDLOOP.
  ENDMETHOD.


  METHOD collapsed_md_and_d_needs_conf.
    " abapGit may collapse this object to a single "_D" delete entry
    DATA(lt_files) = VALUE zcl_abapgit_mcp_guard=>ty_files(
      ( make_file( iv_filename = `zcl_example.clas.abap` iv_lstate = `M` iv_rstate = `D` ) )
      ( make_file( iv_filename = `zcl_example.clas.xml`  iv_lstate = ``  iv_rstate = `D` ) ) ).

    cl_abap_unit_assert=>assert_equals(
      exp = 1
      act = required_count( is_entry = overwrite_entry( zif_abapgit_mcp_sync=>c_action-delete )
                            it_files = lt_files ) ).
  ENDMETHOD.


  METHOD overwrite_action_needs_confirm.
    cl_abap_unit_assert=>assert_equals(
      exp = 1
      act = required_count( is_entry = overwrite_entry( zif_abapgit_mcp_sync=>c_action-overwrite )
                            it_files = VALUE #( ( make_file( iv_lstate = `` iv_rstate = `M` ) ) ) ) ).
  ENDMETHOD.


  METHOD packmove_needs_confirm.
    cl_abap_unit_assert=>assert_equals(
      exp = 1
      act = required_count( is_entry = overwrite_entry( zif_abapgit_mcp_sync=>c_action-packmove )
                            it_files = VALUE #( ( make_file( iv_lstate = `` iv_rstate = `` ) ) ) ) ).
  ENDMETHOD.


  METHOD no_support_needs_confirm.
    cl_abap_unit_assert=>assert_equals(
      exp = 1
      act = required_count( is_entry = overwrite_entry( zif_abapgit_mcp_sync=>c_action-no_support )
                            it_files = VALUE #( ( make_file( iv_lstate = `` iv_rstate = `M` ) ) ) ) ).
  ENDMETHOD.


  METHOD warning_package_needs_confirm.
    DATA(ls_entry) = overwrite_entry( zif_abapgit_mcp_sync=>c_action-package ).
    ls_entry-table = zcl_abapgit_mcp_guard=>c_table-warning_package.

    cl_abap_unit_assert=>assert_equals(
      exp = 1
      act = required_count( is_entry = ls_entry
                            it_files = VALUE #( ( make_file( iv_lstate = `` iv_rstate = `` ) ) ) ) ).
  ENDMETHOD.


  METHOD unknown_table_needs_confirm.
    DATA(ls_entry) = overwrite_entry( zif_abapgit_mcp_sync=>c_action-update ).
    ls_entry-table = `DATA_LOSS`.

    cl_abap_unit_assert=>assert_equals(
      exp = 1
      act = required_count( is_entry = ls_entry
                            it_files = VALUE #( ( make_file( iv_lstate = `` iv_rstate = `M` ) ) ) ) ).
  ENDMETHOD.


  METHOD object_without_files_fails_cl.
    cl_abap_unit_assert=>assert_equals(
      exp = 1
      act = required_count( is_entry = overwrite_entry( zif_abapgit_mcp_sync=>c_action-update )
                            it_files = VALUE #( ) ) ).
  ENDMETHOD.


  METHOD matching_confirmation_covers.
    " Object name and type compare case-insensitively
    cl_abap_unit_assert=>assert_equals(
      exp = 0
      act = required_count( is_entry   = overwrite_entry( zif_abapgit_mcp_sync=>c_action-update )
                            it_files   = VALUE #( ( make_file( iv_lstate = `M` iv_rstate = `` ) ) )
                            it_confirm = VALUE #( ( obj_type = `clas`
                                                    obj_name = `zcl_example`
                                                    action   = zif_abapgit_mcp_sync=>c_action-update ) ) ) ).
  ENDMETHOD.


  METHOD stale_action_does_not_cover.
    " Confirmed for overwrite, but Git changed in between and the entry is now a delete
    cl_abap_unit_assert=>assert_equals(
      exp = 1
      act = required_count( is_entry   = overwrite_entry( zif_abapgit_mcp_sync=>c_action-delete )
                            it_files   = VALUE #( ( make_file( iv_lstate = `M` iv_rstate = `D` ) ) )
                            it_confirm = VALUE #( ( obj_type = c_class
                                                    obj_name = c_name
                                                    action   = zif_abapgit_mcp_sync=>c_action-overwrite ) ) ) ).
  ENDMETHOD.


  METHOD required_entry_lists_files.
    DATA(lt_required) = zcl_abapgit_mcp_guard=>unconfirmed_pull_entries(
      it_entries = VALUE #( ( overwrite_entry( zif_abapgit_mcp_sync=>c_action-delete ) ) )
      it_files   = VALUE #( ( make_file( iv_filename = `zcl_example.clas.abap` iv_lstate = `M` iv_rstate = `D` ) )
                            ( make_file( iv_filename = `zcl_example.clas.xml`  iv_lstate = ``  iv_rstate = `D` ) )
                            ( obj_type = `PROG` obj_name = `ZOTHER` path = `/src/`
                              filename = `zother.prog.abap` lstate = `M` ) )
      it_confirm = VALUE #( ) ).

    cl_abap_unit_assert=>assert_equals( exp = 1 act = lines( lt_required ) ).
    DATA(ls_required) = lt_required[ 1 ].
    cl_abap_unit_assert=>assert_equals( exp = zif_abapgit_mcp_sync=>c_action-delete act = ls_required-action ).
    cl_abap_unit_assert=>assert_equals(
      exp = VALUE zif_abapgit_mcp_sync=>ty_file_states(
              ( path = `/src/` filename = `zcl_example.clas.abap` state = `MD` )
              ( path = `/src/` filename = `zcl_example.clas.xml`  state = `_D` ) )
      act = ls_required-files ).
  ENDMETHOD.

ENDCLASS.


CLASS ltcl_push_rule DEFINITION FINAL FOR TESTING
  DURATION SHORT
  RISK LEVEL HARMLESS.

  PRIVATE SECTION.
    METHODS sample_files
      RETURNING
        VALUE(rt_files) TYPE zcl_abapgit_mcp_guard=>ty_files.

    METHODS git_change_on_selected_blocks  FOR TESTING.
    METHODS git_change_elsewhere_is_fine   FOR TESTING.
    METHODS local_change_only_is_fine      FOR TESTING.
ENDCLASS.


CLASS ltcl_push_rule IMPLEMENTATION.

  METHOD sample_files.
    rt_files = VALUE #(
      ( obj_type = `PROG` obj_name = `ZSELECTED` path = `/src/` filename = `zselected.prog.abap` rstate = `M` )
      ( obj_type = `PROG` obj_name = `ZSELECTED` path = `/src/` filename = `zselected.prog.xml` )
      ( obj_type = `PROG` obj_name = `ZLOCAL`    path = `/src/` filename = `zlocal.prog.abap`    lstate = `M` )
      ( obj_type = `PROG` obj_name = `ZOTHER`    path = `/src/` filename = `zother.prog.abap`    rstate = `M` ) ).
  ENDMETHOD.


  METHOD git_change_on_selected_blocks.
    cl_abap_unit_assert=>assert_equals(
      exp = VALUE string_table( ( `/src/zselected.prog.abap _M` ) )
      act = zcl_abapgit_mcp_guard=>remote_changed_files(
              it_objects = VALUE #( ( obj_type = `prog` obj_name = `zselected` ) )
              it_files   = sample_files( ) ) ).
  ENDMETHOD.


  METHOD git_change_elsewhere_is_fine.
    cl_abap_unit_assert=>assert_initial(
      zcl_abapgit_mcp_guard=>remote_changed_files(
        it_objects = VALUE #( ( obj_type = `PROG` obj_name = `ZLOCAL` ) )
        it_files   = sample_files( ) ) ).
  ENDMETHOD.


  METHOD local_change_only_is_fine.
    cl_abap_unit_assert=>assert_initial(
      zcl_abapgit_mcp_guard=>remote_changed_files(
        it_objects = VALUE #( ( obj_type = `PROG` obj_name = `ZLOCAL` ) )
        it_files   = VALUE #( ( obj_type = `PROG` obj_name = `ZLOCAL` path = `/src/`
                                filename = `zlocal.prog.abap` lstate = `M` ) ) ) ).
  ENDMETHOD.

ENDCLASS.


CLASS ltcl_decidable_state DEFINITION FINAL FOR TESTING
  DURATION SHORT
  RISK LEVEL HARMLESS.

  PRIVATE SECTION.
    METHODS only_known_pairs_are_decidable FOR TESTING.
ENDCLASS.


CLASS ltcl_decidable_state IMPLEMENTATION.

  METHOD only_known_pairs_are_decidable.
    " The pairs zcl_abapgit_objects_check=>warning_overwrite_find handles
    DATA(lt_known) = VALUE string_table( ( `__` ) ( `_A` ) ( `D_` ) ( `DM` ) ( `A_` )
                                         ( `_D` ) ( `MD` ) ( `M_` ) ( `MM` ) ( `_M` ) ).
    DATA(lt_states) = VALUE string_table( ( `` ) ( `A` ) ( `M` ) ( `D` ) ).

    LOOP AT lt_states INTO DATA(lv_lstate).
      LOOP AT lt_states INTO DATA(lv_rstate).
        DATA(lv_pair) = zcl_abapgit_mcp_guard=>state_text( VALUE #( lstate = lv_lstate rstate = lv_rstate ) ).
        cl_abap_unit_assert=>assert_equals(
          exp = xsdbool( line_exists( lt_known[ table_line = lv_pair ] ) )
          act = zcl_abapgit_mcp_guard=>is_decidable_state( iv_lstate = lv_lstate iv_rstate = lv_rstate )
          msg = |state { lv_pair }| ).
      ENDLOOP.
    ENDLOOP.
  ENDMETHOD.

ENDCLASS.


CLASS ltcl_transport_rule DEFINITION FINAL FOR TESTING
  DURATION SHORT
  RISK LEVEL HARMLESS.

  PRIVATE SECTION.
    CONSTANTS c_workbench   TYPE string VALUE `WBREQUEST`.
    CONSTANTS c_customizing TYPE string VALUE `CUREQUEST`.

    METHODS assert_refused
      IMPORTING
        iv_transport            TYPE string
        iv_workbench_required   TYPE abap_bool
        iv_customizing_required TYPE abap_bool
        iv_customizing_preset   TYPE string OPTIONAL.

    METHODS workbench_needs_transport     FOR TESTING.
    METHODS workbench_gets_transport      FOR TESTING RAISING zcx_abapgit_mcp_sync.
    METHODS customizing_preset_only       FOR TESTING RAISING zcx_abapgit_mcp_sync.
    METHODS customizing_preset_is_kept    FOR TESTING RAISING zcx_abapgit_mcp_sync.
    METHODS mixed_without_preset_refused  FOR TESTING.
    METHODS customizing_only_uses_request FOR TESTING RAISING zcx_abapgit_mcp_sync.
    METHODS customizing_only_needs_request FOR TESTING.
ENDCLASS.


CLASS ltcl_transport_rule IMPLEMENTATION.

  METHOD assert_refused.
    DATA lx_error TYPE REF TO zcx_abapgit_mcp_sync.

    TRY.
        zcl_abapgit_mcp_guard=>assign_transports( iv_transport            = iv_transport
                                                  iv_workbench_required   = iv_workbench_required
                                                  iv_customizing_required = iv_customizing_required
                                                  iv_customizing_preset   = iv_customizing_preset ).
      CATCH zcx_abapgit_mcp_sync INTO lx_error.
    ENDTRY.
    cl_abap_unit_assert=>assert_bound( lx_error ).
    cl_abap_unit_assert=>assert_equals( exp = zif_abapgit_mcp_sync=>c_error-transport_required
                                        act = lx_error->mv_code ).
  ENDMETHOD.


  METHOD workbench_needs_transport.
    assert_refused( iv_transport            = ``
                    iv_workbench_required   = abap_true
                    iv_customizing_required = abap_false ).
  ENDMETHOD.


  METHOD workbench_gets_transport.
    cl_abap_unit_assert=>assert_equals(
      exp = VALUE zcl_abapgit_mcp_guard=>ty_transports( workbench = c_workbench )
      act = zcl_abapgit_mcp_guard=>assign_transports( iv_transport            = to_lower( c_workbench )
                                                      iv_workbench_required   = abap_true
                                                      iv_customizing_required = abap_false ) ).
  ENDMETHOD.


  METHOD customizing_preset_only.
    " Table content only, request preset in the repository: a "transport" passed
    " anyway is not needed and must not be checked as a workbench request
    cl_abap_unit_assert=>assert_equals(
      exp = VALUE zcl_abapgit_mcp_guard=>ty_transports( customizing = c_customizing )
      act = zcl_abapgit_mcp_guard=>assign_transports( iv_transport            = c_workbench
                                                      iv_workbench_required   = abap_false
                                                      iv_customizing_required = abap_true
                                                      iv_customizing_preset   = c_customizing ) ).
  ENDMETHOD.


  METHOD customizing_preset_is_kept.
    " Objects and table content: the customizing request comes from the repository setting
    cl_abap_unit_assert=>assert_equals(
      exp = VALUE zcl_abapgit_mcp_guard=>ty_transports( workbench   = c_workbench
                                                        customizing = c_customizing )
      act = zcl_abapgit_mcp_guard=>assign_transports( iv_transport            = c_workbench
                                                      iv_workbench_required   = abap_true
                                                      iv_customizing_required = abap_true
                                                      iv_customizing_preset   = c_customizing ) ).
  ENDMETHOD.


  METHOD mixed_without_preset_refused.
    " One request member cannot carry both a workbench and a customizing request
    assert_refused( iv_transport            = c_workbench
                    iv_workbench_required   = abap_true
                    iv_customizing_required = abap_true ).
  ENDMETHOD.


  METHOD customizing_only_uses_request.
    cl_abap_unit_assert=>assert_equals(
      exp = VALUE zcl_abapgit_mcp_guard=>ty_transports( customizing = c_customizing )
      act = zcl_abapgit_mcp_guard=>assign_transports( iv_transport            = c_customizing
                                                      iv_workbench_required   = abap_false
                                                      iv_customizing_required = abap_true ) ).
  ENDMETHOD.


  METHOD customizing_only_needs_request.
    assert_refused( iv_transport            = ``
                    iv_workbench_required   = abap_false
                    iv_customizing_required = abap_true ).
  ENDMETHOD.

ENDCLASS.
