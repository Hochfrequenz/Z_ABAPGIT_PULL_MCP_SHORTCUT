"! <p class="shorttext synchronized">abapGit sync: what the branch selection needs from abapGit</p>
"! A seam for ZCL_ABAPGIT_MCP_BRANCH: the default implementation talks to an
"! online repository and the Git remote, unit tests use a double. It uses only
"! APIs that exist in old and new abapGit versions.
INTERFACE zif_abapgit_mcp_branch_gw PUBLIC.

  "! Full name of the branch the repository is on, e.g. refs/heads/main
  METHODS selected_branch
    RETURNING
      VALUE(rv_branch) TYPE string.

  "! Full names of the branches on the remote, e.g. refs/heads/main
  "! A failing request to the remote is raised, not answered by an empty list.
  METHODS remote_branches
    RETURNING
      VALUE(rt_branches) TYPE string_table
    RAISING
      zcx_abapgit_exception.

  METHODS select_branch
    IMPORTING
      iv_branch TYPE string
    RAISING
      zcx_abapgit_exception.

ENDINTERFACE.
