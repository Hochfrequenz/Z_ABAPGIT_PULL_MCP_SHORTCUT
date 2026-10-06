"! Object list filter for abapGit's stage logic: only the files of the named
"! objects are staged. abapGit 1.128.0 ships no object-list filter of its own.
CLASS lcl_object_filter DEFINITION FINAL.

  PUBLIC SECTION.
    INTERFACES zif_abapgit_object_filter.

    METHODS constructor
      IMPORTING
        it_objects TYPE zif_abapgit_mcp_sync=>ty_objects.

  PRIVATE SECTION.
    DATA mt_filter TYPE zif_abapgit_definitions=>ty_tadir_tt.

ENDCLASS.


CLASS lcl_object_filter IMPLEMENTATION.

  METHOD constructor.
    mt_filter = VALUE #( FOR ls_object IN it_objects
                         ( pgmid    = 'R3TR'
                           object   = to_upper( ls_object-obj_type )
                           obj_name = to_upper( ls_object-obj_name ) ) ).
  ENDMETHOD.


  METHOD zif_abapgit_object_filter~get_filter.
    rt_filter = mt_filter.
  ENDMETHOD.

ENDCLASS.
