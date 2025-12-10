local M = {}

M.query = [[
  (
   (infix_expression
     left: (string) @organization
     operator: (operator_identifier) @op
     right: (string) @artifact
     (#any-of? @op "%" "%%")
   ) @dep_org_art
  )
  (
   (infix_expression
     left: (wildcard)
     operator: (operator_identifier) @opv
     right: (_) @version
     (#eq? @opv "%")
   ) @dep_version
  )
]]

return M
