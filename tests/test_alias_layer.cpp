#include "unittest/test.h"
#include "myengine/aliases.h"
#include "myengine/registry.h"
#include <fstream>
#include <cstdio>

class TestMyEngine : public TestBase {
public:
	TestMyEngine() { TestManager::registerTestModule(this); }
	const char *getName() { return "TestMyEngine"; }

	void runTests(IGameDef *gamedef) {
		TEST(testAliasResolution);
	}

	void testAliasResolution() {
		// 1. Setup Registry (Manual for isolation)
		Registry::clear();
		Registry::register_path("player_system.physics_component.air_resistance_value");

		// 2. Setup Alias Table
		std::string test_alias_file = "test_alias_map_unit.txt";
		{
			std::ofstream ofs(test_alias_file);
			ofs << "player.physics.air_resistance = player_system.physics_component.air_resistance_value" << std::endl;
			ofs << "stale.alias = nonexistent.path" << std::endl;
		}

		AliasLayer::load_aliases(test_alias_file);

		// Case 1: A valid alias resolves to the correct real path
		UASSERTEQ(std::string, AliasLayer::resolve("player.physics.air_resistance"), "player_system.physics_component.air_resistance_value");

		// Case 2: An unknown path (no alias) returns the original path
		UASSERTEQ(std::string, AliasLayer::resolve("unknown.path"), "unknown.path");

		// Case 3: A stale alias (alias exists but real path is gone) returns target
		UASSERTEQ(std::string, AliasLayer::resolve("stale.alias"), "nonexistent.path");

		// Cleanup
		std::remove(test_alias_file.c_str());
	}
};

static TestMyEngine g_test_instance;
