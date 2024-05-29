# ActiveRecordRules: a primer

This document is intended to get you started with using the ActiveRecordRules library. By the end of this document you should know:
 1. how to write rules to match your objects,
 2. how rules are matched, and
 3. how matches are executed.

## The anatomy of a rule

Rules consist of three parts: a _name_, a set of _constraints_, and a _body_. The simplest rule matches a single record:

```
rule Mark new users as "active" # <- name
  User(<id>)                    # <- constraints
on match                        # <- body
  User.find(id).active!         # <- body
```

This rule will match whenever a `User` object is created, and will fire its body.

## Constraints

The above rule is a minimal example, though. It provides no benefit over a regular `ActiveRecord` callback. The main benefit of rules is that they can match _multiple_ records in the same set of constraints.

```
rule Mark members of the "admin" group as admins
  User(id = <user_id>, admin = false)     # <- constraints
  GroupMember(<user_id>, <group_id>)      # <- constraints
  Group(id = <group_id>, name = "admins") # <- constraints
on match
  User.find(user_id).update!(admin: true)
```

This rule shows several features of rules: (a) matching on multiple records, (b) constant conditions on records, and (c) variable binding. In order for this rule to match, there must be records that match this _entire_ condition. That is: there must be a `User` record with its `admin` flag set to false, a `Group` with the name `"admins"`, and a `GroupMember` record which ties them both together. This rule will match for _every matching set of records_, and execute its body.

Any names mentioned within angle bracket (e.g. `<name>`) refer to a variable. Any bare names (e.g. `name`) refer to a record attribute. Variables are bound to values by constraining them with the `=` operator: `<variable_name> = attribute_name`. Where the variable and attribute names are the same you can omit the attribute name: `<id>` is syntax sugar for `<id> = id`.

Constraining a variable with `=` _grounds_ the variable's value, ensuring that it exactly matches another value. This can be done multiple times, and all the bound values must agree (i.e. in the above example, the `<user_id>` variable ensures that the `User`'s `id` matches the `GroupMember`'s `user_id`). A rule with non-ground variables will raise an error.

Besides establishing bindings, operators can also be used to constrain other values (e.g. `admin = false`, above). In all, there are six operators: `=`, `!=`, `<=`, `<`, `>`, `>=`. Each corresponds to the equivalent SQL operator. These can be combined by the familiar `and` and `or` boolean operators. Note that an `=` operator can only bind a variable at the "top-level" - nesting them within an `and` or `or` will not ground the variable.

## Bodies

When a rule matches, it then needs to _do_ something. This is where rule bodies come in. They specify Ruby code to be run when a rule matches. All the variables used in the constraints are bound as Ruby variables for the body to use. Rather than a single body, each rule may have any of three different bodies: `on match`, `on update`, and `on unmatch`.

- `on match` bodies are the most obvious. They are executed when there are records which match the rule, which didn't previously. This can be because a new record has been created, or because an existing record has been updated to now match the rule, or even (in the case of negation) because a record has been destroyed.
- `on update` bodies are executed when the rule matches for a set of records which are already matched, but with different variable values. Matching records are tracked by `id`, and each variable is provided as a pair of `name.old` and `name.new`, referring to the variable value before and after the change. If this is not provided, it defaults to running `on unmatch` with the old values, and then `on match` with the new values.
- `on unmatch` bodies are executed when the rule ceases to match for a set of records. In this case the variables are provided with the _last matched values_.
