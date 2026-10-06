CLASS ltcl_status_mapping DEFINITION FINAL FOR TESTING
  DURATION SHORT
  RISK LEVEL HARMLESS.

  PRIVATE SECTION.
    METHODS every_code_has_its_status FOR TESTING.
    METHODS error_body_carries_details FOR TESTING.
ENDCLASS.


CLASS ltcl_status_mapping IMPLEMENTATION.

  METHOD every_code_has_its_status.
    TYPES: BEGIN OF ty_case,
             code   TYPE string,
             status TYPE i,
           END OF ty_case.
    DATA lt_cases TYPE STANDARD TABLE OF ty_case WITH EMPTY KEY.

    lt_cases = VALUE #(
      ( code = zif_abapgit_mcp_sync=>c_error-repo_not_found       status = 404 )
      ( code = zif_abapgit_mcp_sync=>c_error-repo_ambiguous       status = 409 )
      ( code = zif_abapgit_mcp_sync=>c_error-object_not_in_repo   status = 422 )
      ( code = zif_abapgit_mcp_sync=>c_error-credentials_missing  status = 422 )
      ( code = zif_abapgit_mcp_sync=>c_error-credentials_rejected status = 422 )
      ( code = zif_abapgit_mcp_sync=>c_error-transport_required   status = 422 )
      ( code = zif_abapgit_mcp_sync=>c_error-no_modifiable_task   status = 422 )
      ( code = zif_abapgit_mcp_sync=>c_error-requirements_not_met status = 422 )
      ( code = zif_abapgit_mcp_sync=>c_error-remote_changed       status = 409 )
      ( code = zif_abapgit_mcp_sync=>c_error-git_error            status = 424 )
      ( code = zif_abapgit_mcp_sync=>c_error-bad_request          status = 400 )
      ( code = zif_abapgit_mcp_sync=>c_error-internal             status = 500 ) ).

    LOOP AT lt_cases INTO DATA(ls_case).
      cl_abap_unit_assert=>assert_equals( exp = ls_case-status
                                          act = zcx_abapgit_mcp_sync=>http_status_of( ls_case-code )
                                          msg = ls_case-code ).
    ENDLOOP.
  ENDMETHOD.


  METHOD error_body_carries_details.
    DATA lx_error TYPE REF TO zcx_abapgit_mcp_sync.

    TRY.
        zcx_abapgit_mcp_sync=>raise( iv_code    = zif_abapgit_mcp_sync=>c_error-remote_changed
                                     iv_text    = `pull first`
                                     it_details = VALUE #( ( `/src/zexample.prog.abap _M` ) ) ).
      CATCH zcx_abapgit_mcp_sync INTO lx_error.
    ENDTRY.

    cl_abap_unit_assert=>assert_equals(
      exp = VALUE zif_abapgit_mcp_sync=>ty_error( code    = zif_abapgit_mcp_sync=>c_error-remote_changed
                                                  message = `pull first`
                                                  details = VALUE #( ( `/src/zexample.prog.abap _M` ) ) )
      act = lx_error->to_error( ) ).
  ENDMETHOD.

ENDCLASS.
