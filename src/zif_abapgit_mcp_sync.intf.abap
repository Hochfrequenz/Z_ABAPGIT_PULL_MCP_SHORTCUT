"! <p class="shorttext synchronized">abapGit sync: contract types for list, pull and push</p>
"! Types and constants of the JSON contract served under /sap/bc/adt/abapgitsync/.
"! Component names match the JSON member names; the Simple Transformations
"! ZABAPGIT_MCP_* map them one to one.
INTERFACE zif_abapgit_mcp_sync PUBLIC.

  TYPES:
    BEGIN OF ty_repo,
      key             TYPE string,
      name            TYPE string,
      url             TYPE string,
      package         TYPE string,
      branch          TYPE string,
      offline         TYPE abap_bool,
      deserialized_at TYPE string,
      deserialized_by TYPE string,
    END OF ty_repo,
    ty_repos TYPE STANDARD TABLE OF ty_repo WITH EMPTY KEY.

  TYPES:
    BEGIN OF ty_object,
      obj_type TYPE string,
      obj_name TYPE string,
    END OF ty_object,
    ty_objects TYPE STANDARD TABLE OF ty_object WITH EMPTY KEY.

  TYPES:
    BEGIN OF ty_confirmation,
      obj_type TYPE string,
      obj_name TYPE string,
      action   TYPE string,
    END OF ty_confirmation,
    ty_confirmations TYPE STANDARD TABLE OF ty_confirmation WITH EMPTY KEY.

  TYPES:
    BEGIN OF ty_pull_request,
      repo      TYPE string,
      transport TYPE string,
      confirm   TYPE ty_confirmations,
    END OF ty_pull_request.

  TYPES:
    BEGIN OF ty_file_state,
      path     TYPE string,
      filename TYPE string,
      state    TYPE string,
    END OF ty_file_state,
    ty_file_states TYPE STANDARD TABLE OF ty_file_state WITH EMPTY KEY.

  TYPES:
    BEGIN OF ty_confirmation_required,
      obj_type TYPE string,
      obj_name TYPE string,
      action   TYPE string,
      text     TYPE string,
      files    TYPE ty_file_states,
    END OF ty_confirmation_required,
    ty_confirmations_required TYPE STANDARD TABLE OF ty_confirmation_required WITH EMPTY KEY.

  TYPES:
    BEGIN OF ty_log_entry,
      type     TYPE string,
      text     TYPE string,
      obj_type TYPE string,
      obj_name TYPE string,
    END OF ty_log_entry,
    ty_log TYPE STANDARD TABLE OF ty_log_entry WITH EMPTY KEY.

  TYPES:
    BEGIN OF ty_repo_ref,
      name    TYPE string,
      url     TYPE string,
      package TYPE string,
    END OF ty_repo_ref.

  TYPES:
    BEGIN OF ty_pull_result,
      status                 TYPE string,
      repo                   TYPE ty_repo_ref,
      confirmations_required TYPE ty_confirmations_required,
      log                    TYPE ty_log,
    END OF ty_pull_result.

  TYPES:
    BEGIN OF ty_push_request,
      repo    TYPE string,
      objects TYPE ty_objects,
      message TYPE string,
      dry_run TYPE abap_bool,
    END OF ty_push_request.

  TYPES:
    BEGIN OF ty_author,
      name  TYPE string,
      email TYPE string,
    END OF ty_author.

  TYPES:
    BEGIN OF ty_push_file,
      path     TYPE string,
      filename TYPE string,
      action   TYPE string,
    END OF ty_push_file,
    ty_push_files TYPE STANDARD TABLE OF ty_push_file WITH EMPTY KEY.

  TYPES:
    BEGIN OF ty_push_result,
      status TYPE string,
      commit TYPE string,
      author TYPE ty_author,
      files  TYPE ty_push_files,
    END OF ty_push_result.

  TYPES:
    BEGIN OF ty_error,
      code    TYPE string,
      message TYPE string,
      details TYPE string_table,
    END OF ty_error.

  CONSTANTS:
    BEGIN OF c_status,
      pulled             TYPE string VALUE `pulled`,
      needs_confirmation TYPE string VALUE `needs_confirmation`,
      pushed             TYPE string VALUE `pushed`,
      dry_run            TYPE string VALUE `dry_run`,
      nothing_to_push    TYPE string VALUE `nothing_to_push`,
    END OF c_status.

  CONSTANTS:
    BEGIN OF c_action,
      add        TYPE string VALUE `add`,
      update     TYPE string VALUE `update`,
      overwrite  TYPE string VALUE `overwrite`,
      delete     TYPE string VALUE `delete`,
      delete_add TYPE string VALUE `delete_add`,
      packmove   TYPE string VALUE `packmove`,
      no_support TYPE string VALUE `no_support`,
      package    TYPE string VALUE `package`,
      rm         TYPE string VALUE `rm`,
    END OF c_action.

  CONSTANTS:
    BEGIN OF c_error,
      repo_not_found       TYPE string VALUE `REPO_NOT_FOUND`,
      repo_ambiguous       TYPE string VALUE `REPO_AMBIGUOUS`,
      object_not_in_repo   TYPE string VALUE `OBJECT_NOT_IN_REPO`,
      credentials_missing  TYPE string VALUE `CREDENTIALS_MISSING`,
      credentials_rejected TYPE string VALUE `CREDENTIALS_REJECTED`,
      transport_required   TYPE string VALUE `TRANSPORT_REQUIRED`,
      no_modifiable_task   TYPE string VALUE `NO_MODIFIABLE_TASK`,
      requirements_not_met TYPE string VALUE `REQUIREMENTS_NOT_MET`,
      remote_changed       TYPE string VALUE `REMOTE_CHANGED`,
      git_error            TYPE string VALUE `GIT_ERROR`,
      bad_request          TYPE string VALUE `BAD_REQUEST`,
      internal             TYPE string VALUE `INTERNAL`,
    END OF c_error.

ENDINTERFACE.
