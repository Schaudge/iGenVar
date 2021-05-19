cmake_minimum_required (VERSION 3.11)

include (cmake/app_datasources.cmake)

# Get Hash-value via bash: 'shasum -a 256 path/to/file.ending

# copies file to <build>/data/simulated.minimap2.hg19.coordsorted_cutoff.sam
# This file is a small cutoff created by:
# head -20999 simulated.minimap2.hg19.coordsorted.sam | tail -4 > simulated.minimap2.hg19.coordsorted_cutoff.sam
declare_datasource (FILE simulated.minimap2.hg19.coordsorted_cutoff.sam
                    URL ${CMAKE_SOURCE_DIR}/test/data/simulated.minimap2.hg19.coordsorted_cutoff.sam
                    URL_HASH SHA256=e59b42c85ed309faf8b3d2f1a8e64a9ccd0a47becd1cb291144efd56be0aa4f9)

# copies file to <build>/data/paired_end_mini_example.sam
declare_datasource (FILE paired_end_mini_example.sam
                    URL ${CMAKE_SOURCE_DIR}/test/data/mini_example/paired_end_mini_example.sam
                    URL_HASH SHA256=a4134ef84c4a2d6aa57f00966a69ca3c54036dc3d17f418427ce4fc6bb7e87ff)

# copies file to <build>/data/single_end_mini_example.sam
declare_datasource (FILE single_end_mini_example.sam
                    URL ${CMAKE_SOURCE_DIR}/test/data/mini_example/single_end_mini_example.sam
                    URL_HASH SHA256=ea89fb00c802e5136ca8dd32362648c8192652a34078bfa25b8ae78695a27cd6)

# copies file to <build>/data/output_err.txt
declare_datasource (FILE output_err.txt
                    URL ${CMAKE_SOURCE_DIR}/test/data/mini_example/output_err.txt
                    URL_HASH SHA256=cf57c74ea68b825c234b12e5d4dfd99478f1026cf316313b7b555fc531a111fb)

# copies file to <build>/data/output_res.txt
declare_datasource (FILE output_res.txt
                    URL ${CMAKE_SOURCE_DIR}/test/data/mini_example/output_res.txt
                    URL_HASH SHA256=2940c08ebd08798d40f5c0249ea78b9d73a22228e3015f3ab450422d189e5fae)
