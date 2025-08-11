class_name GroupFilter
extends RefCounted

var _all_bitmask: int = 0
var _any_bitmask: int = 0
var _except_bitmask: int = 0

static var _next_flag: int = 1
static var _flags_by_group: Dictionary[StringName, int] = {}

#region Setup
## Returns a copy of this group filter
func duplicate() -> GroupFilter:
    var group_filter := GroupFilter.new()
    group_filter._all_bitmask = _all_bitmask
    group_filter._any_bitmask = _any_bitmask
    group_filter._except_bitmask = _except_bitmask
    return group_filter

## Returns a group filter that matches pieces that are in specified group
func with(group: StringName) -> GroupFilter:
    var group_filter := duplicate()
    group_filter._all_bitmask = group_filter._all_bitmask | group_to_flag(group)
    return group_filter

## Returns a group filter that matches pieces that aren't in specified group
func without(group: StringName) -> GroupFilter:
    var group_filter := duplicate()
    group_filter._except_bitmask = group_filter._except_bitmask | group_to_flag(group)
    return group_filter

## Returns a group filter that matches pieces that are in all of specified groups
func with_all(groups: Array[StringName]) -> GroupFilter:
    var group_filter := duplicate()
    group_filter._all_bitmask = group_filter._all_bitmask | groups_to_flags(groups)
    return group_filter

## Returns a group filter that matches pieces that are in any of specified groups
func with_any(groups: Array[StringName]) -> GroupFilter:
    var group_filter := duplicate()
    group_filter._any_bitmask = group_filter._any_bitmask | groups_to_flags(groups)
    return group_filter
    
## Returns a group filter that matches pieces that aren't in any of specified groups
func without_any(groups: Array[StringName]) -> GroupFilter:
    var group_filter := duplicate()
    group_filter._except_bitmask = group_filter._except_bitmask | groups_to_flags(groups)
    return group_filter
#endregion

#region Matches
## Does `piece` pass our filter?
func matches_3d(piece: Piece3D) -> bool:
    if _all_bitmask and not (piece.flags & _all_bitmask == _all_bitmask):
        # Failed to match all groups
        return false
    if _any_bitmask and not (piece.flags & _any_bitmask != 0):
        # Failed to match any groups
        return false
    if _except_bitmask and not (piece.flags & _except_bitmask == 0):
        # Failed to match except groups
        return false
    return true
#endregion

#region Flags
## Convert a group (StringName) to a bitwise flag (int) for filtering pieces
static func group_to_flag(group: StringName) -> int:
    if not _flags_by_group.has(group):
        var flag := _next_flag
        _flags_by_group[group] = flag
        _next_flag = _next_flag << 1
        return flag
    return _flags_by_group[group]

## Convert an array of groups (Array[StringName]) to bitwise flags (int) for filtering pieces
static func groups_to_flags(groups: Array[StringName]) -> int:
    var flags := 0
    for group in groups:
        flags = flags | group_to_flag(group)
    return flags
#endregion
