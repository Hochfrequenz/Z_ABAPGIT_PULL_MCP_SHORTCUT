"! <p class="shorttext synchronized">abapGit sync: ADT resource application</p>
"! Registers the resources under /sap/bc/adt/abapgitsync/. The path lies
"! outside /sap/bc/adt/abapgit/ on purpose: the deprecated abapGit ADT_Backend
"! registers /sap/bc/adt/abapgit/*. Pattern from Z_ABABGIT_ADT_EXPORT.
CLASS zcl_abapgit_mcp_adt_app DEFINITION
  PUBLIC
  INHERITING FROM cl_adt_disc_res_app_base
  FINAL
  CREATE PUBLIC.

  PUBLIC SECTION.
    METHODS if_adt_rest_rfc_application~get_static_uri_path REDEFINITION.

  PROTECTED SECTION.
    METHODS get_application_title REDEFINITION.
    METHODS register_resources REDEFINITION.

ENDCLASS.



CLASS zcl_abapgit_mcp_adt_app IMPLEMENTATION.


  METHOD get_application_title.

    result = `abapGit Sync for MCP` ##NO_TEXT.

  ENDMETHOD.


  METHOD if_adt_rest_rfc_application~get_static_uri_path.

    result = `/sap/bc/adt/abapgitsync` ##NO_TEXT.

  ENDMETHOD.


  METHOD register_resources.

    CONSTANTS lc_scheme TYPE string VALUE `http://www.sap.com/adt/categories/abapgitsync` ##NO_TEXT.

    registry->register_discoverable_resource( url             = `/repos`
                                              handler_class   = `ZCL_ABAPGIT_MCP_ADT_REPOS`
                                              description     = `abapGit repositories`
                                              category_scheme = lc_scheme
                                              category_term   = `repos` ) ##NO_TEXT.
    registry->register_discoverable_resource( url             = `/pull`
                                              handler_class   = `ZCL_ABAPGIT_MCP_ADT_PULL`
                                              description     = `Pull an abapGit repository`
                                              category_scheme = lc_scheme
                                              category_term   = `pull` ) ##NO_TEXT.
    registry->register_discoverable_resource( url             = `/push`
                                              handler_class   = `ZCL_ABAPGIT_MCP_ADT_PUSH`
                                              description     = `Push selected objects`
                                              category_scheme = lc_scheme
                                              category_term   = `push` ) ##NO_TEXT.

  ENDMETHOD.

ENDCLASS.
