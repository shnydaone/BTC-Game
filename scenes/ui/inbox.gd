class_name Inbox
extends RefCounted
## Messages for this session: historical news, alerts and info, newest first. Lives with
## the game screen; a loaded game starts with an empty inbox.

const MAX_MESSAGES: int = 200

var messages: Array[Dictionary] = []  # {date, kind, text, read}


func add(date: String, m: Dictionary) -> void:
	if m.is_empty() or m["kind"] == "toast":
		return
	messages.push_front({"date": date, "kind": m["kind"], "text": m["text"], "read": false})
	if messages.size() > MAX_MESSAGES:
		messages.pop_back()


func unread() -> int:
	return messages.filter(func(m: Dictionary) -> bool: return not m["read"]).size()


func mark_all_read() -> void:
	for m: Dictionary in messages:
		m["read"] = true
