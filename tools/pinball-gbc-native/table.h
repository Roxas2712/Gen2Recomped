#pragma once
#include "gbrt.h"
#include <vector>
// Separate host presentation: scratch guest calls never touch the live guest.
class GBCTable {
    GBContext* scratch=nullptr;
public:
    ~GBCTable();
    bool compose(GBContext*,std::vector<uint8_t>&);
    unsigned failures=0;
};
