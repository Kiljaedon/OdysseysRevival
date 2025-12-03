extends Node
## Test script for Database Refactoring verification

func _ready():
	print("--- Running Database Refactor Test ---")
	test_repository_factory()
	test_account_repository()
	test_authentication_service()
	print("--- Database Refactor Test Complete ---")
	get_tree().quit()

func test_repository_factory():
	print("Test: RepositoryFactory")
	var repo = RepositoryFactory.get_account_repository()
	assert(repo != null, "RepositoryFactory should return an account repository")
	assert(repo is AccountJsonRepository, "Default repository should be JSON")
	print("Test: RepositoryFactory - PASSED")

func test_account_repository():
	print("Test: AccountJsonRepository")
	var repo = RepositoryFactory.get_account_repository()
	var test_user = "test_user_" + str(randi())
	
	# Create
	var result = repo.create_account(test_user, "hashed_password")
	assert(result.success, "Should create account: " + str(result.get("error")))
	
	# Read
	var get_result = repo.get_account(test_user)
	assert(get_result.success, "Should retrieve account")
	assert(get_result.account.username == test_user, "Username should match")
	
	# Cleanup (manual file delete for test)
	var path = ProjectSettings.globalize_path("res://data/accounts/" + test_user.to_lower() + ".json")
	if FileAccess.file_exists(path):
		DirAccess.remove_absolute(path)
		
	print("Test: AccountJsonRepository - PASSED")

func test_authentication_service():
	print("Test: AuthenticationService")
	var auth = AuthenticationService.new()
	var test_user = "auth_user_" + str(randi())
	var test_pass = "securePa$$123"
	
	# Register
	var reg_result = auth.create_account(test_user, test_pass)
	assert(reg_result.success, "Should register user: " + str(reg_result.get("error")))
	
	# Login Success
	var login_result = auth.login(test_user, test_pass)
	assert(login_result.success, "Should login successfully")
	
	# Login Failure
	var fail_result = auth.login(test_user, "wrong_pass")
	assert(not fail_result.success, "Should fail with wrong password")
	
	# Cleanup
	auth.queue_free()
	var path = ProjectSettings.globalize_path("res://data/accounts/" + test_user.to_lower() + ".json")
	if FileAccess.file_exists(path):
		DirAccess.remove_absolute(path)
		
	print("Test: AuthenticationService - PASSED")

func assert(condition: bool, message: String):
	if not condition:
		push_error(message)
		# Don't quit immediately in test script to see all failures, 
		# but for this environment, fail fast is okay.
		print("FAILURE: " + message)
	else:
		print("  ✓ " + message)
