cmake_minimum_required (VERSION 3.16)

add_api_test (input_file_test.cpp)
target_use_datasources (input_file_test FILES simulated.minimap2.hg19.coordsorted_cutoff.sam)

add_api_test (debruijn_graph_test.cpp)

add_api_test (detection_test.cpp)

add_api_test (clustering_test.cpp)

# add_api_test (refinement_test.cpp)

add_api_test (snp_indel_test.cpp)
target_use_datasources (snp_indel_test FILES simulated.minimap2.hg19.coordsorted_cutoff.sam)

add_api_test (structures_test.cpp)
