"! <p class="shorttext synchronized">abapGit sync: guard rules for pull and push</p>
"! Pure rules without access to abapGit or the database, so that they can be
"! tested in isolation. ZCL_ABAPGIT_MCP_SYNC feeds them with the per-file
"! status table (ZCL_ABAPGIT_REPO_STATUS=&gt;calculate) and the decision tables
"! of the deserialize checks.
CLASS zcl_abapgit_mcp_guard DEFINITION
  PUBLIC
  FINAL
  CREATE PUBLIC.

  PUBLIC SECTION.

    CONSTANTS:
      BEGIN OF c_table,
        overwrite       TYPE string VALUE `OVERWRITE`,
        warning_package TYPE string VALUE `WARNING_PACKAGE`,
      END OF c_table.

    TYPES:
      "! One file of the repository status, lstate = SAP side, rstate = Git side
      BEGIN OF ty_file,
        obj_type TYPE string,
        obj_name TYPE string,
        path     TYPE string,
        filename TYPE string,
        lstate   TYPE string,
        rstate   TYPE string,
      END OF ty_file,
      ty_files TYPE STANDARD TABLE OF ty_file WITH EMPTY KEY.

    TYPES:
      "! One entry of one decision table of the deserialize checks
      BEGIN OF ty_decision_entry,
        table    TYPE string,
        obj_type TYPE string,
        obj_name TYPE string,
        action   TYPE string,
        text     TYPE string,
      END OF ty_decision_entry,
      ty_decision_entries TYPE STANDARD TABLE OF ty_decision_entry WITH EMPTY KEY.

    "! Pull rule. Returns every entry that needs an explicit confirmation and is
    "! not covered by it_confirm. An empty result means every entry may be
    "! decided with 'Y'. The rule is evaluated per file of the object, never on
    "! the collapsed state of the overwrite entry.
    CLASS-METHODS unconfirmed_pull_entries
      IMPORTING
        it_entries         TYPE ty_decision_entries
        it_files           TYPE ty_files
        it_confirm         TYPE zif_abapgit_mcp_sync=>ty_confirmations
      RETURNING
        VALUE(rt_required) TYPE zif_abapgit_mcp_sync=>ty_confirmations_required.

    "! Push rule. Returns the files of the selected objects whose Git side
    "! changed since the last pull, as "&lt;path&gt;&lt;filename&gt; &lt;state&gt;".
    "! Pushing them would revert the Git change.
    CLASS-METHODS remote_changed_files
      IMPORTING
        it_objects        TYPE zif_abapgit_mcp_sync=>ty_objects
        it_files          TYPE ty_files
      RETURNING
        VALUE(rt_details) TYPE string_table.

    "! Whether abapGit's deserialize checks can classify this file state.
    "! For any other pair, zcl_abapgit_objects_check ends in ASSERT 0 = 1,
    "! a short dump that no caller can catch.
    CLASS-METHODS is_decidable_state
      IMPORTING
        iv_lstate           TYPE csequence
        iv_rstate           TYPE csequence
      RETURNING
        VALUE(rv_decidable) TYPE abap_bool.

    "! Two-character state, blank written as '_': lstate 'M' + rstate ' ' = 'M_'
    CLASS-METHODS state_text
      IMPORTING
        is_file        TYPE ty_file
      RETURNING
        VALUE(rv_text) TYPE string.

  PRIVATE SECTION.

    CLASS-METHODS files_of_object
      IMPORTING
        it_files        TYPE ty_files
        iv_obj_type     TYPE string
        iv_obj_name     TYPE string
      RETURNING
        VALUE(rt_files) TYPE ty_files.

    CLASS-METHODS is_auto_confirmed
      IMPORTING
        is_entry               TYPE ty_decision_entry
        it_object_files        TYPE ty_files
      RETURNING
        VALUE(rv_auto_confirm) TYPE abap_bool.

    CLASS-METHODS is_confirmed
      IMPORTING
        is_entry            TYPE ty_decision_entry
        it_confirm          TYPE zif_abapgit_mcp_sync=>ty_confirmations
      RETURNING
        VALUE(rv_confirmed) TYPE abap_bool.

ENDCLASS.



CLASS ZCL_ABAPGIT_MCP_GUARD IMPLEMENTATION.


  METHOD files_of_object.

    DATA(lv_type) = to_upper( iv_obj_type ).
    DATA(lv_name) = to_upper( iv_obj_name ).

    LOOP AT it_files INTO DATA(ls_file).
      IF to_upper( ls_file-obj_type ) = lv_type AND to_upper( ls_file-obj_name ) = lv_name.
        APPEND ls_file TO rt_files.
      ENDIF.
    ENDLOOP.

  ENDMETHOD.


  METHOD is_auto_confirmed.

    " Only Git changed: an overwrite entry with a plain add, update or delete,
    " and no file of the object carries a local state. An object without any
    " file in the status table cannot be proven clean, so it fails closed.
    IF is_entry-table <> c_table-overwrite
       OR it_object_files IS INITIAL
       OR (     is_entry-action <> zif_abapgit_mcp_sync=>c_action-add
            AND is_entry-action <> zif_abapgit_mcp_sync=>c_action-update
            AND is_entry-action <> zif_abapgit_mcp_sync=>c_action-delete ).
      RETURN.
    ENDIF.

    LOOP AT it_object_files TRANSPORTING NO FIELDS WHERE lstate IS NOT INITIAL.
      RETURN.
    ENDLOOP.

    rv_auto_confirm = abap_true.

  ENDMETHOD.


  METHOD is_confirmed.

    " The action must match too: a confirmation given for "overwrite" does not
    " carry over when Git changed in between and the entry became "delete".
    LOOP AT it_confirm INTO DATA(ls_confirm).
      IF     to_upper( ls_confirm-obj_type ) = to_upper( is_entry-obj_type )
         AND to_upper( ls_confirm-obj_name ) = to_upper( is_entry-obj_name )
         AND to_lower( ls_confirm-action )   = to_lower( is_entry-action ).
        rv_confirmed = abap_true.
        RETURN.
      ENDIF.
    ENDLOOP.

  ENDMETHOD.


  METHOD is_decidable_state.

    DATA(lv_state) = state_text( VALUE #( lstate = iv_lstate rstate = iv_rstate ) ).
    rv_decidable = xsdbool( lv_state = `__` OR lv_state = `_A` OR lv_state = `D_` OR lv_state = `DM`
                         OR lv_state = `A_` OR lv_state = `_D` OR lv_state = `MD` OR lv_state = `M_`
                         OR lv_state = `MM` OR lv_state = `_M` ).

  ENDMETHOD.


  METHOD remote_changed_files.

    LOOP AT it_objects INTO DATA(ls_object).
      DATA(lt_object_files) = files_of_object( it_files    = it_files
                                               iv_obj_type = ls_object-obj_type
                                               iv_obj_name = ls_object-obj_name ).
      LOOP AT lt_object_files INTO DATA(ls_file) WHERE rstate IS NOT INITIAL.
        APPEND |{ ls_file-path }{ ls_file-filename } { state_text( ls_file ) }| TO rt_details.
      ENDLOOP.
    ENDLOOP.

  ENDMETHOD.


  METHOD state_text.

    rv_text = COND #( WHEN is_file-lstate IS INITIAL THEN `_` ELSE is_file-lstate )
           && COND #( WHEN is_file-rstate IS INITIAL THEN `_` ELSE is_file-rstate ).

  ENDMETHOD.


  METHOD unconfirmed_pull_entries.

    LOOP AT it_entries INTO DATA(ls_entry).
      DATA(lt_object_files) = files_of_object( it_files    = it_files
                                               iv_obj_type = ls_entry-obj_type
                                               iv_obj_name = ls_entry-obj_name ).

      IF is_auto_confirmed( is_entry        = ls_entry
                            it_object_files = lt_object_files ) = abap_true
         OR is_confirmed( is_entry   = ls_entry
                          it_confirm = it_confirm ) = abap_true.
        CONTINUE.
      ENDIF.

      APPEND VALUE #( obj_type = ls_entry-obj_type
                      obj_name = ls_entry-obj_name
                      action   = ls_entry-action
                      text     = ls_entry-text
                      files    = VALUE #( FOR ls_file IN lt_object_files
                                          ( path     = ls_file-path
                                            filename = ls_file-filename
                                            state    = state_text( ls_file ) ) ) )
        TO rt_required.
    ENDLOOP.

  ENDMETHOD.
ENDCLASS.
