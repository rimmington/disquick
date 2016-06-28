{lib}:
serviceSet:

# TODO: rename this function to something like closedServiceSet?

let
  recurseServices = s: [s] ++ lib.concatMap recurseServices s.attrs.dependsOn or [];
  allServices = lib.concatMap recurseServices (builtins.attrValues serviceSet);
  allUsers = lib.concatMap (s: if s.attrs ? user then [s.attrs.user] else []) allServices;
  usersConflict = u1: u2: u1 != u2;  # TODO: This could be more lenient
  anyUsersConflict = (lib.fold (u: {acc, err}:
    let
      res = { acc = acc // (builtins.listToAttrs [{ name = u.name; value = u; }]); err = false; };
      u1 = builtins.getAttr u.name acc;
    in if builtins.hasAttr u.name acc
      then if usersConflict u1 u
        then throw "User definitions conflict: ${builtins.toJSON u1} and ${builtins.toJSON u}"
        else res
      else res
    ) { acc = {}; err = false; } allUsers).err;
in assert !anyUsersConflict; serviceSet
