CLASS ltcl_repo_match DEFINITION FINAL FOR TESTING
  DURATION SHORT
  RISK LEVEL HARMLESS.

  PRIVATE SECTION.
    METHODS url_normalisation      FOR TESTING.
    METHODS unknown_repo_no_hit    FOR TESTING RAISING zcx_abapgit_exception.
ENDCLASS.


CLASS ltcl_repo_match IMPLEMENTATION.

  METHOD url_normalisation.
    DATA(lv_expected) = `HTTPS://GITHUB.COM/EXAMPLE/REPO`.
    cl_abap_unit_assert=>assert_equals(
      exp = lv_expected act = zcl_abapgit_mcp_repo_match=>normalise_url( `https://github.com/example/repo` ) ).
    cl_abap_unit_assert=>assert_equals(
      exp = lv_expected act = zcl_abapgit_mcp_repo_match=>normalise_url( `https://github.com/example/repo.git` ) ).
    cl_abap_unit_assert=>assert_equals(
      exp = lv_expected act = zcl_abapgit_mcp_repo_match=>normalise_url( `https://github.com/Example/Repo/` ) ).
  ENDMETHOD.


  METHOD unknown_repo_no_hit.
    cl_abap_unit_assert=>assert_initial(
      zcl_abapgit_mcp_repo_match=>find_online_repos( `https://example.invalid/no/such/repo.git` ) ).
  ENDMETHOD.

ENDCLASS.
