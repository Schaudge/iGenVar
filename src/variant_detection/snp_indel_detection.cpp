#include <iostream>

#include <seqan3/alphabet/cigar/cigar.hpp>
#include <seqan3/core/debug_stream.hpp>
#include <seqan3/io/sam_file/input.hpp>

#include "iGenVar.hpp"
#include "variant_detection/bam_functions.hpp"          // check the sam flags
#include "variant_detection/snp_indel_detection.hpp"    // detect_snp_and_indel

void detect_snp_and_indel(std::filesystem::path const & reads_filename, uint64_t min_var_length)
{
    // Get the header information and set the necessary fields.
    using sam_fields = seqan3::fields<seqan3::field::flag,       // 2: FLAG
                                      seqan3::field::ref_id,     // 3: RNAME
                                      seqan3::field::ref_offset, // 4: POS
                                      seqan3::field::mapq,       // 5: MAPQ
                                      seqan3::field::cigar>;     // 6: CIGAR

    seqan3::sam_file_input reads_file{reads_filename, sam_fields{}};
    auto const & header = reads_file.header();

    // Check that the file is sorted.
    if (header.sorting != "coordinate")
        throw seqan3::format_error{"ERROR: Input file must be sorted by coordinate (e.g. samtools sort)"};

    // Prepare one activity vector per reference sequence.
    std::vector<std::vector<unsigned>> activity(header.ref_id_info.size()); // number of ref sequences

    for (auto && record : reads_file)
    {
        seqan3::sam_flag const flag = record.flag();                            // 2: FLAG
        int32_t const ref_id        = record.reference_id().value_or(-1);       // 3: RNAME
        int32_t ref_pos             = record.reference_position().value_or(-1); // 4: POS

        // Skip reads with certain properties.
        if (hasFlagUnmapped(flag) ||
            hasFlagSecondary(flag) ||
            hasFlagDuplicate(flag) ||
            record.mapping_quality() < 20 ||
            ref_id < 0 ||
            ref_pos < 0)
        {
            continue;
        }

        // Check if we have already allocated the length of the reference sequence.
        if (activity[ref_id].empty())
            activity[ref_id].resize(std::get<0>(header.ref_id_info[ref_id])); // length of reference sequence

        // Track the current position within the read.
        unsigned read_pos = 0;

        // Step through the CIGAR string.
        for (auto && [length, operation] : record.cigar_sequence())
        {
            // Skip long variants.
            if (length >= min_var_length)
            {
                read_pos += length;
                ref_pos += length;
                continue;
            }

            // Case distinction for cigar elements.
            switch (operation.to_char())
            {
                case 'I':
                case 'S': // insertion or soft clip
                {
                    activity[ref_id][ref_pos] += 1u;
                    if (gVerbose)
                        seqan3::debug_stream << "SI activity[" << ref_id << "," << ref_pos << "]\t"
                                             << activity[ref_id][ref_pos] << std::endl;
                    read_pos += length;
                    break;
                }
                case 'D': // deletion
                {
                    for (unsigned idx = 0; idx < length; ++idx)
                        ++activity[ref_id][ref_pos + idx];
                    if (gVerbose)
                        seqan3::debug_stream << "D  activity[" << ref_id << "," << ref_pos << "]\t"
                                             << activity[ref_id][ref_pos] << std::endl;
                    ref_pos += length;
                    break;
                }
                default: // ignore match, mismatch, hard clipping, padding, and skipped region
                { // TODO (joergi-w 30.09.2021) mismatches are ignored but should be verified with the reference
                    ref_pos += length;
                    read_pos += length;
                }
            }
        }
    }

    // Extract active regions from activity profile.
    size_t const window_width = 5u; // another idea: (min_var_length + 1) / 2;
    size_t const activity_threshold = 2;
    std::deque<std::string> const ref_ids = reads_file.header().ref_ids();

    for (size_t ref_id = 0; ref_id < activity.size(); ++ref_id)
    {
        // Skip reference sequences that are not contained in the reads.
        auto const & av = activity[ref_id];
        if (av.empty())
            continue;

        size_t window_score = 0; // sum of the activities inside the window
        size_t pos;              // the current position in the genome sequence
        bool active = false;     // whether `pos` is inside an active region

        // Initialisation of a window of length min_var_length.
        for (pos = 0; pos < window_width && pos < av.size(); ++pos)
            window_score += av[pos];

        seqan3::debug_stream << "Active regions of " << ref_ids[ref_id] << ":";
        while (pos < av.size())
        {
            // Check for start or end of an active region.
            if (!active && window_score >= activity_threshold)
            {
                seqan3::debug_stream << " [" << pos - window_width;
                active = true;
            }
            else if (active && window_score < activity_threshold)
            {
                seqan3::debug_stream << "," << pos - 1u << "]";
                active = false;
            }

            // Advance the sliding window.
            window_score -= av[pos - window_width];
            window_score += av[pos];
            ++pos;
        }

        // Handle the case if the genome ends in an active region.
        if (active)
            seqan3::debug_stream << "," << pos - 1u << "]";

        seqan3::debug_stream << std::endl;
    }
}
