"! <p class="shorttext synchronized">abapGit sync: POST /sap/bc/adt/abapgitsync/push</p>
CLASS zcl_abapgit_mcp_adt_push DEFINITION
  PUBLIC
  INHERITING FROM zcl_abapgit_mcp_adt_res
  FINAL
  CREATE PUBLIC.

  PUBLIC SECTION.
    METHODS post REDEFINITION.

ENDCLASS.



CLASS zcl_abapgit_mcp_adt_push IMPLEMENTATION.


  METHOD post.

    TRY.
        DATA(ls_request) = zcl_abapgit_mcp_json=>push_request_from_json( request_body( request ) ).
        respond( io_response = response
                 iv_status   = cl_rest_status_code=>gc_success_ok
                 iv_json     = zcl_abapgit_mcp_json=>push_result_to_json(
                                 NEW zcl_abapgit_mcp_sync( )->push( ls_request ) ) ).
      CATCH cx_root INTO DATA(lx_error).
        respond_error( io_response = response
                       ix_error    = lx_error ).
    ENDTRY.

  ENDMETHOD.

ENDCLASS.
