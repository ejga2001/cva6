//
// Created by enrique on 8/12/24.
//
#include <iostream>
#include <fstream>
#include <nlohmann/json.hpp>
#include <vector>

using json = nlohmann::json;

// Struct to represent the JSON data
struct GBPCombination {
    std::string vpc_i;
    int bht_update_i_valid;
    int bht_update_i_taken;
    int flush_bp_i;
    int debug_mode_i;
    int nr_entries;
    int instr_per_fetch;
};

// Function to load JSON data into a vector of GBPCombination
std::vector<GBPCombination> load_combinations(const std::string& filename) {
    // Open the file
    std::ifstream file(filename);
    if (!file.is_open()) {
        throw std::runtime_error("Failed to open file: " + filename);
    }

    // Parse the JSON file
    json json_data;
    file >> json_data;

    // Convert JSON to vector of GBPCombination
    std::vector<GBPCombination> combinations;
    for (const auto& entry : json_data) {
        GBPCombination comb;
        comb.vpc_i = entry.at("vpc_i").get<std::string>();
        comb.bht_update_i_valid = entry.at("bht_update_i_valid").get<int>();
        comb.bht_update_i_taken = entry.at("bht_update_i_taken").get<int>();
        comb.flush_bp_i = entry.at("flush_bp_i").get<int>();
        comb.debug_mode_i = entry.at("debug_mode_i").get<int>();
        comb.nr_entries = entry.at("nr_entries").get<int>();
        comb.instr_per_fetch = entry.at("instr_per_fetch").get<int>();
        combinations.push_back(comb);
    }

    return combinations;
}

int main() {
    const std::string filename = "gbp_combinations.json";

    try {
        // Load the combinations from JSON
        std::vector<GBPCombination> combinations = load_combinations(filename);

        // Print out the first few combinations as a demo
        std::cout << "Loaded " << combinations.size() << " combinations.\n";
        for (size_t i = 0; i < combinations.size(); ++i) {
            const auto& comb = combinations[i];
            std::cout << "Combination " << i + 1 << ":\n";
            std::cout << "  vpc_i: " << comb.vpc_i << "\n";
            std::cout << "  bht_update_i_valid: " << comb.bht_update_i_valid << "\n";
            std::cout << "  bht_update_i_taken: " << comb.bht_update_i_taken << "\n";
            std::cout << "  flush_bp_i: " << comb.flush_bp_i << "\n";
            std::cout << "  debug_mode_i: " << comb.debug_mode_i << "\n";
            std::cout << "  nr_entries: " << comb.nr_entries << "\n";
            std::cout << "  instr_per_fetch: " << comb.instr_per_fetch << "\n\n";
        }
    } catch (const std::exception& e) {
        std::cerr << "Error: " << e.what() << "\n";
        return 1;
    }

    return 0;
}