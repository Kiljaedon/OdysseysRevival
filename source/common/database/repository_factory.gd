class_name RepositoryFactory
extends Node

# Configuration
const USE_SQLITE = false

# Repository Instances (Singletons for this run)
static var _account_repo = null
static var _character_repo = null

static func get_account_repository():
	if _account_repo == null:
		if USE_SQLITE:
			# Placeholder for future SQL implementation
			# _account_repo = AccountSqlRepository.new()
			push_warning("SQLite not implemented, falling back to JSON")
			_account_repo = AccountJsonRepository.new()
		else:
			_account_repo = AccountJsonRepository.new()
	return _account_repo

static func get_character_repository():
	if _character_repo == null:
		if USE_SQLITE:
			# Placeholder for future SQL implementation
			# _character_repo = CharacterSqlRepository.new()
			push_warning("SQLite not implemented, falling back to JSON")
			_character_repo = CharacterJsonRepository.new()
		else:
			_character_repo = CharacterJsonRepository.new()
	return _character_repo
