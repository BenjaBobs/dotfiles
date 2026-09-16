;; Textobjects for SQL.
;;
;; nvim-treesitter-textobjects ships queries for ~70 languages and SQL is not
;; one of them, so without this file `af`/`if`, `ac`/`ic`, `aa`/`ia` and the
;; `]f`/`[f` motions are silently dead in SQL buffers. The captures here are
;; exactly the ones bh/plugins/text-manipulation.lua maps.
;;
;; Grammar is derekstride/tree-sitter-sql (see the pin in nvim-treesitter's
;; parsers.lua). Two of its habits shape everything below: every keyword is a
;; *named* node (`keyword_select`, `keyword_by`, ... 371 of them), and `;` is
;; anonymous and lives in `program` rather than inside `statement`.

;; `af` / `if` -- a whole statement. SQL has no function, and the statement is
;; the unit you actually yank, delete and move as one thing. There is no
;; smaller "body" to strip, so inner and outer are the same range.
(statement) @function.outer

(statement) @function.inner

;; `ac` / `ic` -- a CTE. `ac` covers `name AS ( ... )` including the name;
;; `ic` takes just the query inside the parentheses, which is what you want
;; when rewriting one step of a pipeline.
(cte) @class.outer

(cte
  (statement) @class.inner)

;; `aa` / `ia` -- the comma-separated things.
;;
;; `outer` swallows one comma so `daa` leaves a well-formed list behind. The two
;; patterns per container are the upstream idiom: every element takes the comma
;; *before* it, except the first, which takes the one after instead.
;;
;; The leading `.` anchors to "first named child" and ignores the opening paren.
;; That only works where a container holds nothing but its elements -- true for
;; the five below, but not for `order_by`/`group_by`, whose leading keywords are
;; named nodes, so those anchor to `keyword_by` instead.

;; SELECT a, b, c
(select_expression
  "," @parameter.outer
  .
  (term) @parameter.inner @parameter.outer)

(select_expression
  .
  (term) @parameter.inner @parameter.outer
  .
  ","? @parameter.outer)

;; IN (1, 2, 3), VALUES (...), f(x, y)
(list
  "," @parameter.outer
  .
  (_) @parameter.inner @parameter.outer)

(list
  .
  (_) @parameter.inner @parameter.outer
  .
  ","? @parameter.outer)

;; CREATE TABLE t (id INT, name TEXT)
(column_definitions
  "," @parameter.outer
  .
  (column_definition) @parameter.inner @parameter.outer)

(column_definitions
  .
  (column_definition) @parameter.inner @parameter.outer
  .
  ","? @parameter.outer)

;; UPDATE t SET a = 1, b = 2
(assignment_list
  "," @parameter.outer
  .
  (assignment) @parameter.inner @parameter.outer)

(assignment_list
  .
  (assignment) @parameter.inner @parameter.outer
  .
  ","? @parameter.outer)

;; PARTITION BY (a, b), and other parenthesised bare column lists
(ordered_columns
  "," @parameter.outer
  .
  (column) @parameter.inner @parameter.outer)

(ordered_columns
  .
  (column) @parameter.inner @parameter.outer
  .
  ","? @parameter.outer)

;; ORDER BY a DESC, b
(order_by
  "," @parameter.outer
  .
  (order_target) @parameter.inner @parameter.outer)

(order_by
  (keyword_by)
  .
  (order_target) @parameter.inner @parameter.outer
  .
  ","? @parameter.outer)

;; GROUP BY a, b
(group_by
  "," @parameter.outer
  .
  (_) @parameter.inner @parameter.outer)

(group_by
  (keyword_by)
  .
  (_) @parameter.inner @parameter.outer
  .
  ","? @parameter.outer)
