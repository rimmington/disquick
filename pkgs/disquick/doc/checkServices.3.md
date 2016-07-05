checkServices(3) - check for conflicts between services
=======================================================

## SYNOPSIS

`pkgs.checkServices` _services_ `->` checkedServices

## DESCRIPTION

`checkServices` checks for certain conflicts in the definitions of a set of services. It accepts an attrset of `mkService`(3) values.

## RETURN VALUE

_services_ if all checks pass, otherwise a `throw`-style (catchable with `tryEval`) exception.

## SEE ALSO

`mkService`(3)
