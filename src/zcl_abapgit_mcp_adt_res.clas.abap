"! <p class="shorttext synchronized">abapGit sync: base of the ADT resources</p>
"! JSON request and response handling shared by the resources under
"! /sap/bc/adt/abapgitsync/. Every answer carries a JSON body; errors use the
"! contract shape code, message, details. 401 and 403 are never answered,
"! because ADT clients re-authenticate and replay the request.
CLASS zcl_abapgit_mcp_adt_res DEFINITION
  PUBLIC
  INHERITING FROM cl_adt_rest_resource
  ABSTRACT
  CREATE PUBLIC.

  PROTECTED SECTION.

    METHODS request_body
      IMPORTING
        io_request     TYPE REF TO if_adt_rest_request
      RETURNING
        VALUE(rv_body) TYPE string.

    METHODS respond
      IMPORTING
        io_response TYPE REF TO if_adt_rest_response
        iv_status   TYPE i
        iv_json     TYPE string.

    METHODS respond_error
      IMPORTING
        io_response TYPE REF TO if_adt_rest_response
        ix_error    TYPE REF TO cx_root.

ENDCLASS.



CLASS zcl_abapgit_mcp_adt_res IMPLEMENTATION.


  METHOD request_body.

    rv_body = io_request->get_inner_rest_request( )->get_entity( )->get_string_data( ).

  ENDMETHOD.


  METHOD respond.

    DATA(li_entity) = io_response->get_inner_rest_response( )->create_entity( ).
    li_entity->set_content_type( iv_media_type = `application/json` ).
    li_entity->set_string_data( iv_json ).
    io_response->set_status( iv_status ).

  ENDMETHOD.


  METHOD respond_error.

    DATA lx_sync TYPE REF TO zcx_abapgit_mcp_sync.

    TRY.
        lx_sync ?= ix_error.
      CATCH cx_sy_move_cast_error.
        lx_sync = NEW #( previous = ix_error
                         iv_code  = zif_abapgit_mcp_sync=>c_error-internal
                         iv_text  = ix_error->get_text( ) ).
    ENDTRY.

    respond( io_response = io_response
             iv_status   = lx_sync->http_status( )
             iv_json     = zcl_abapgit_mcp_json=>error_to_json( lx_sync->to_error( ) ) ).

  ENDMETHOD.

ENDCLASS.
