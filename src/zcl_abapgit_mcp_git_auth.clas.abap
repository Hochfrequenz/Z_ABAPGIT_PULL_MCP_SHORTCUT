"! <p class="shorttext synchronized">abapGit sync: credential preflight against the Git host</p>
"! Sends GET &lt;repo&gt;/info/refs?service=git-&lt;service&gt; before abapGit
"! itself talks to the Git host, so that a missing or rejected credential
"! surfaces as a specific contract error instead of an abapGit exception.
"!
"! Credentials come only from the caller's own SM59 HTTP destination
"! (default ZGIT_&lt;SAP user&gt;). After a successful preflight through the
"! destination, the Authorization header of that request is handed to
"! ZCL_ABAPGIT_LOGIN_MANAGER, which abapGit's HTTP layer loads before every
"! request. If the header is not exposed, nothing is handed over and abapGit
"! relies on its user exit (create_http_client), if one is installed.
"! The header value is never logged or returned.
CLASS zcl_abapgit_mcp_git_auth DEFINITION
  PUBLIC
  FINAL
  CREATE PUBLIC.

  PUBLIC SECTION.

    CONSTANTS:
      BEGIN OF c_service,
        upload_pack  TYPE string VALUE `upload-pack`,
        receive_pack TYPE string VALUE `receive-pack`,
      END OF c_service.

    "! @parameter iv_destination | SM59 destination, default ZGIT_&lt;SAP user&gt;
    METHODS constructor
      IMPORTING
        iv_destination TYPE rfcdest OPTIONAL.

    "! @parameter iv_credentials_required | abap_true for push: no anonymous fallback
    METHODS preflight
      IMPORTING
        iv_url                  TYPE string
        iv_service              TYPE string
        iv_credentials_required TYPE abap_bool
      RAISING
        zcx_abapgit_mcp_sync.

    METHODS get_destination
      RETURNING
        VALUE(rv_destination) TYPE rfcdest.

    "! Scheme and authority of a repository URL, e.g. https://github.com
    CLASS-METHODS url_base
      IMPORTING
        iv_url         TYPE string
      RETURNING
        VALUE(rv_base) TYPE string.

    "! Path of a repository URL, e.g. /owner/repo.git
    CLASS-METHODS url_path
      IMPORTING
        iv_url         TYPE string
      RETURNING
        VALUE(rv_path) TYPE string.

    "! Host of a repository URL in lower case, without scheme and port
    CLASS-METHODS url_host
      IMPORTING
        iv_url         TYPE string
      RETURNING
        VALUE(rv_host) TYPE string.

  PRIVATE SECTION.

    DATA mv_destination TYPE rfcdest.

    METHODS destination_client
      IMPORTING
        iv_url           TYPE string
      RETURNING
        VALUE(ri_client) TYPE REF TO if_http_client.

    METHODS anonymous_client
      IMPORTING
        iv_url           TYPE string
      RETURNING
        VALUE(ri_client) TYPE REF TO if_http_client
      RAISING
        zcx_abapgit_mcp_sync.

    METHODS info_refs_status
      IMPORTING
        ii_client        TYPE REF TO if_http_client
        iv_url           TYPE string
        iv_service       TYPE string
      RETURNING
        VALUE(rv_status) TYPE i
      RAISING
        zcx_abapgit_mcp_sync.

    METHODS hand_over_credentials
      IMPORTING
        ii_client TYPE REF TO if_http_client
        iv_url    TYPE string
      RAISING
        zcx_abapgit_mcp_sync.

ENDCLASS.



CLASS ZCL_ABAPGIT_MCP_GIT_AUTH IMPLEMENTATION.


  METHOD anonymous_client.

    DATA(lo_proxy) = NEW zcl_abapgit_proxy_config( ).

    cl_http_client=>create_by_url(
      EXPORTING
        url                = url_base( iv_url )
        ssl_id             = zcl_abapgit_exit=>get_instance( )->get_ssl_id( )
        proxy_host         = lo_proxy->get_proxy_url( iv_url )
        proxy_service      = lo_proxy->get_proxy_port( iv_url )
      IMPORTING
        client             = ri_client
      EXCEPTIONS
        argument_not_found = 1
        plugin_not_active  = 2
        internal_error     = 3
        OTHERS             = 4 ).
    IF sy-subrc <> 0.
      zcx_abapgit_mcp_sync=>raise(
        iv_code = zif_abapgit_mcp_sync=>c_error-git_error
        iv_text = |Cannot create an HTTP client for { url_host( iv_url ) } (error { sy-subrc })| ).
    ENDIF.

  ENDMETHOD.


  METHOD constructor.

    mv_destination = COND #( WHEN iv_destination IS INITIAL
                             THEN |ZGIT_{ sy-uname }|
                             ELSE iv_destination ).

  ENDMETHOD.


  METHOD destination_client.

    DATA lv_server TYPE rfcdisplay-rfchost.

    " Only the host is read, never the logon data. No S_RFC_ADM check: the
    " destination is the caller's own, and its use is checked by S_ICF.
    CALL FUNCTION 'RFC_READ_HTTP_DESTINATION'
      EXPORTING
        destination             = mv_destination
        authority_check         = space
      IMPORTING
        server                  = lv_server
      EXCEPTIONS
        authority_not_available = 1
        destination_not_exist   = 2
        information_failure     = 3
        internal_failure        = 4
        no_http_destination     = 5
        OTHERS                  = 6.
    IF sy-subrc <> 0 OR to_lower( condense( lv_server ) ) <> url_host( iv_url ).
      RETURN.
    ENDIF.

    cl_http_client=>create_by_destination(
      EXPORTING
        destination              = mv_destination
      IMPORTING
        client                   = ri_client
      EXCEPTIONS
        argument_not_found       = 1
        destination_not_found    = 2
        destination_no_authority = 3
        plugin_not_active        = 4
        internal_error           = 5
        OTHERS                   = 6 ).
    IF sy-subrc <> 0.
      CLEAR ri_client.
    ENDIF.

  ENDMETHOD.


  METHOD get_destination.

    rv_destination = mv_destination.

  ENDMETHOD.


  METHOD hand_over_credentials.

    DATA(lv_authorization) = ii_client->request->get_header_field( `authorization` ).
    IF lv_authorization IS INITIAL.
      RETURN.
    ENDIF.

    " The login manager never overwrites an entry for a host, so clear first
    zcl_abapgit_login_manager=>clear( ).
    TRY.
        zcl_abapgit_login_manager=>save( iv_uri           = iv_url
                                         iv_authorization = lv_authorization ).
      CATCH zcx_abapgit_exception INTO DATA(lx_error).
        zcx_abapgit_mcp_sync=>raise( iv_code     = zif_abapgit_mcp_sync=>c_error-internal
                                     iv_text     = lx_error->get_text( )
                                     ix_previous = lx_error ).
    ENDTRY.

  ENDMETHOD.


  METHOD info_refs_status.

    DATA lv_message TYPE string.

    ii_client->propertytype_logon_popup = if_http_client=>co_disabled.
    ii_client->request->set_method( if_http_request=>co_request_method_get ).
    ii_client->request->set_version( if_http_request=>co_protocol_version_1_1 ).
    ii_client->request->set_header_field( name  = `user-agent`
                                          value = zcl_abapgit_http=>get_agent( ) ).
    cl_http_utility=>set_request_uri(
      request = ii_client->request
      uri     = |{ url_path( iv_url ) }/info/refs?service=git-{ iv_service }| ).

    ii_client->send( EXCEPTIONS OTHERS = 1 ).
    IF sy-subrc = 0.
      ii_client->receive( EXCEPTIONS OTHERS = 1 ).
    ENDIF.
    IF sy-subrc <> 0.
      ii_client->get_last_error( IMPORTING message = lv_message ).
      ii_client->close( ).
      zcx_abapgit_mcp_sync=>raise(
        iv_code = zif_abapgit_mcp_sync=>c_error-git_error
        iv_text = |No connection to { url_host( iv_url ) }: { lv_message }| ).
    ENDIF.

    ii_client->response->get_status( IMPORTING code = rv_status ).

  ENDMETHOD.


  METHOD preflight.

    DATA(li_client) = destination_client( iv_url ).

    IF li_client IS NOT BOUND.
      IF iv_credentials_required = abap_true.
        zcx_abapgit_mcp_sync=>raise(
          iv_code = zif_abapgit_mcp_sync=>c_error-credentials_missing
          iv_text = |No usable SM59 HTTP destination { mv_destination } for host { url_host( iv_url ) }| ).
      ENDIF.

      li_client = anonymous_client( iv_url ).
      DATA(lv_anonymous_status) = info_refs_status( ii_client  = li_client
                                                    iv_url     = iv_url
                                                    iv_service = iv_service ).
      li_client->close( ).
      CASE lv_anonymous_status.
        WHEN 200.
          RETURN.
        WHEN 401 OR 404.
          " GitHub answers 404 for a private repository requested without credentials
          zcx_abapgit_mcp_sync=>raise(
            iv_code = zif_abapgit_mcp_sync=>c_error-credentials_missing
            iv_text = |Git host requires credentials (HTTP { lv_anonymous_status }); | &&
                      |create the SM59 HTTP destination { mv_destination }| ).
        WHEN OTHERS.
          zcx_abapgit_mcp_sync=>raise(
            iv_code = zif_abapgit_mcp_sync=>c_error-git_error
            iv_text = |Git host answered HTTP { lv_anonymous_status } to info/refs| ).
      ENDCASE.
    ENDIF.

    DATA(lv_status) = info_refs_status( ii_client  = li_client
                                        iv_url     = iv_url
                                        iv_service = iv_service ).
    CASE lv_status.
      WHEN 200.
        hand_over_credentials( ii_client = li_client
                               iv_url    = iv_url ).
        li_client->close( ).
      WHEN 401 OR 403 OR 404.
        li_client->close( ).
        zcx_abapgit_mcp_sync=>raise(
          iv_code = zif_abapgit_mcp_sync=>c_error-credentials_rejected
          iv_text = |Git host rejected the credentials of { mv_destination } (HTTP { lv_status })| ).
      WHEN OTHERS.
        li_client->close( ).
        zcx_abapgit_mcp_sync=>raise(
          iv_code = zif_abapgit_mcp_sync=>c_error-git_error
          iv_text = |Git host answered HTTP { lv_status } to info/refs| ).
    ENDCASE.

  ENDMETHOD.


  METHOD url_base.

    DATA(lv_path) = url_path( iv_url ).
    rv_base = substring( val = iv_url len = strlen( iv_url ) - strlen( lv_path ) ).

  ENDMETHOD.


  METHOD url_host.

    DATA(lv_rest) = iv_url.
    FIND FIRST OCCURRENCE OF `://` IN lv_rest MATCH OFFSET DATA(lv_offset).
    IF sy-subrc = 0.
      lv_rest = substring( val = lv_rest off = lv_offset + 3 ).
    ENDIF.
    SPLIT lv_rest AT `/` INTO rv_host DATA(lv_path) ##NEEDED.
    SPLIT rv_host AT `:` INTO rv_host DATA(lv_port) ##NEEDED.
    rv_host = to_lower( rv_host ).

  ENDMETHOD.


  METHOD url_path.

    DATA(lv_start) = 0.
    FIND FIRST OCCURRENCE OF `://` IN iv_url MATCH OFFSET DATA(lv_scheme_end).
    IF sy-subrc = 0.
      lv_start = lv_scheme_end + 3.
    ENDIF.
    FIND FIRST OCCURRENCE OF `/` IN SECTION OFFSET lv_start OF iv_url MATCH OFFSET DATA(lv_path_start).
    IF sy-subrc = 0.
      rv_path = substring( val = iv_url off = lv_path_start ).
    ENDIF.

  ENDMETHOD.
ENDCLASS.
