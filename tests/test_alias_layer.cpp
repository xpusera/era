#include "myengine/aliases.h"
#include "myengine/registry.h"
#include <iostream>
#include <cassert>
#include <vector>
#include <fstream>
#include <cstdio>

// Mocking required macros and types
#define infostream std::cout
#define warningstream std::cerr
#define errorstream std::cerr
#define verbosestream std::cout
#define dstream std::cout

// External trim from mock
std::string trim(const std::string& s);

int main() {
    // 1. Setup Alias Table
    std::string test_alias_file = "test_alias_map.txt";
    {
        std::ofstream ofs(test_alias_file);
        ofs << "player.physics.air_resistance = player_system.physics_component.air_resistance_value" << std::endl;
        ofs << "stale.alias = nonexistent.path" << std::endl;
    }

    AliasLayer::load_aliases(test_alias_file);

    // 2. Setup Registry
    Registry::register_path("player_system.physics_component.air_resistance_value");

    // Case 1: A valid alias resolves to the correct real path
    std::string resolved = AliasLayer::resolve("player.physics.air_resistance");
    std::cout << "Test Case 1: Resolve valid alias -> " << resolved << std::endl;
    assert(resolved == "player_system.physics_component.air_resistance_value");

    // Case 2: An unknown path (no alias, no generated path) returns the original path
    resolved = AliasLayer::resolve("unknown.path");
    std::cout << "Test Case 2: Resolve unknown path -> " << resolved << std::endl;
    assert(resolved == "unknown.path");

    // Case 3: A stale alias (alias exists but real path is gone) logs the warning and returns target
    std::cout << "Test Case 3: Resolve stale alias (should see warning below)" << std::endl;
    resolved = AliasLayer::resolve("stale.alias");
    std::cout << "Test Case 3: Resolved stale alias -> " << resolved << std::endl;
    assert(resolved == "nonexistent.path");

    std::cout << "All tests passed!" << std::endl;

    // Cleanup
    std::remove(test_alias_file.c_str());

    return 0;
}
