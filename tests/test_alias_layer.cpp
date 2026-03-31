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
		Registry::clear();
		Registry::register_path("player_system.physics_component.air_resistance_value");

		std::string test_alias_file = "test_alias_map_unit.txt";
		{
			std::ofstream ofs(test_alias_file);
			ofs << "player.physics.air_resistance = player_system.physics_component.air_resistance_value" << std::endl;
			ofs << "stale.alias = nonexistent.path" << std::endl;
		}

		AliasLayer::load_aliases(test_alias_file);

		UASSERTEQ(std::string, AliasLayer::resolve("player.physics.air_resistance"), "player_system.physics_component.air_resistance_value");
		UASSERTEQ(std::string, AliasLayer::resolve("unknown.path"), "unknown.path");
		UASSERTEQ(std::string, AliasLayer::resolve("stale.alias"), "nonexistent.path");

		std::remove(test_alias_file.c_str());
	}
};

static TestMyEngine g_test_instance;
