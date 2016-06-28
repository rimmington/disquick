{lib}:
serviceSet:

# TODO: rename this function to something like closedServiceSet?

let
  allServices = builtins.attrValues serviceSet;
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
  anyMissingServices =
    let
      missing = lib.subtractLists (map (s: s.attrs) allServices) allServicesAndDependencies;
      allServicesAndDependencies = lib.unique (lib.concatMap recurse allServices);
      recurse = s: [s.attrs] ++ lib.concatMap recurse s.attrs.dependsOn or [];
    in if missing == []
      then false
      else throw "Services depended on but not in service set: ${builtins.toJSON missing}";
in
  assert !anyMissingServices;
  assert !anyUsersConflict;
  serviceSet
