#include "variant_detection/variant_output.hpp"

#include <chrono>   // for std::chrono::system_clock
#include <ctime>    // for std::localtime, std::time, std::time_t
#include <iomanip>  // for std::put_time
#include <iostream> // for std::cout

#include <seqan3/alphabet/views/to_char.hpp>                // for seqan3::views::to_char
#include <seqan3/core/debug_stream.hpp>                     // for seqan3::debug_stream
#include <seqan3/core/debug_stream/detail/to_string.hpp>    // for seqan3::detail::to_string

using namespace bio::alphabet::literals;
using namespace std::string_literals;

std::string transTime()
{
    std::stringstream text_stream;
    const std::chrono::time_point<std::chrono::system_clock> now = std::chrono::system_clock::now();
    const std::time_t rawtime = std::chrono::system_clock::to_time_t(now);
    text_stream << std::put_time(std::localtime(&rawtime), "%F %T");
    std::string time_string = text_stream.str();
    return time_string;
}

void write_header(std::map<std::string, int32_t> & references_lengths,
                  std::string sample_name,
                  bio::io::var::header & hdr)
{
    hdr.file_format = "VCFv4.3";
    // Default:
    // hdr.filters.push_back({ .id = "PASS", .description = "All filters passed"});
    hdr.infos.push_back({ .id = "END", .number = 1, .type_id = bio::io::var::value_type_id::int32,
                          .description = "End position of SV called."});
    hdr.infos.push_back({ .id = "SVLEN", .number = 1, .type_id = bio::io::var::value_type_id::int32,
                          .description = "Difference in length between REF and ALT alleles."});
    hdr.infos.push_back({ .id = "iGenVar_SVLEN", .number = 1, .type_id = bio::io::var::value_type_id::int32,
                          .description = "Length of SV called."});
    hdr.infos.push_back({ .id = "SVTYPE", .number = 1, .type_id = bio::io::var::value_type_id::string,
                          .description = "Type of SV called."});
    hdr.formats.push_back({ .id = "GT", .number = 1, .type_id = bio::io::var::value_type_id::string,
                          .description = "Genotype"});

    for (auto const & [id, length] : references_lengths)
        hdr.contigs.push_back({ .id = id, .length = length});

    hdr.other_lines = {"filedate="s + transTime(),
                       "source=iGenVarCaller",
                       "ALT=<ID=DEL,Description=\"Deletion\">",
                       "ALT=<ID=DUP:TANDEM,Description=\"Tandem Duplication\">",
                       "ALT=<ID=INS,Description=\"Insertion of novel sequence\">"};
    hdr.column_labels = {"CHROM", "POS", "ID", "REF", "ALT", "QUAL", "FILTER", "INFO", "FORMAT", sample_name};
}

void write_record(Cluster const & cluster,
                  cmd_arguments const & args,
                  bool & found_SV,
                  bio::io::var::record<> & record)
{
    Breakend mate1 = cluster.get_average_mate1();
    Breakend mate2 = cluster.get_average_mate2();

    record.chrom = mate1.seq_name;
    // Increment position by 1 because VCF is 1-based
    record.pos = mate1.position + 1;
    // TODO (irallia 23.02.22): add global RECORD_ID
    record.id = ".";
    // TODO (irallia 23.02.22): add reference
    record.ref = "N"_dna5;
    record.qual = cluster.get_cluster_size();
    record.filter = {"PASS"};
    record.genotypes.clear();
    record.genotypes.push_back({ .id = "GT", .value = std::vector{"./."s}});
    record.info.clear();

    if (mate1.seq_name == mate2.seq_name)
    {
        if (mate1.orientation == strand::forward)
        {
            size_t const insert_size = cluster.get_average_inserted_sequence_size();
            int const distance = mate2.position - mate1.position - 1;
            int sv_length{};
            int sv_length_iGenVar{};
            std::string sv_type;

            // Tandem Duplication
            // In case of a small deletion inside of a duplication, the distance is a small positive value
            if (cluster.get_common_tandem_dup_count() > 0 && static_cast<uint64_t>(distance) <= args.max_tol_deleted_length)
            {
                record.alt = {"<DUP:TANDEM>"};
                // Increment end by 1 because VCF is 1-based
                record.info.push_back({.id = "END", .value = mate2.position + 1});
                sv_length = distance + 2;
                sv_length_iGenVar = insert_size;
                sv_type = "DUP";
            }
            // Deletion OR Inversion
            else if (distance > 0)
            {
                // Inversion
                // An Inversion consists of 2 Breakpoints, thus it looks like a deletion with an inserted sequence
                if (insert_size >= args.min_var_length)
                {
                    // Increment position by 1 because INV mate1 points on its last element
                    record.pos += 1;
                    record.alt = {"<INV>"};
                    // Increment end by 1 because VCF is 1-based
                    // Increment end by 1 because inversion ends one base before mate2 begins
                    record.info.push_back({.id = "END", .value = mate2.position + 1});
                    sv_length = distance;
                    sv_length_iGenVar = sv_length;
                    sv_type = "INV";
                }
                // Deletion
                // In case of a small insertion inside of a deletion, the insert_size is a small positive value.
                else if (insert_size <= args.max_tol_inserted_length)
                {
                    record.alt = {"<DEL>"};
                    // Increment end by 1 because VCF is 1-based
                    // Decrement end by 1 because deletion ends one base before mate2 begins
                    record.info.push_back({.id = "END", .value = mate2.position});
                    sv_length = -distance;
                    sv_length_iGenVar = sv_length;
                    sv_type = "DEL";
                }
            }
            // Insertion (sv_length is positive)
            // In case of a small deletion inside of an insertion, the distance is a small positive value
            else if (insert_size > 0 && static_cast<uint64_t>(distance) <= args.max_tol_deleted_length)
            {
                record.alt = {"<INS>"};
                // Increment end by 1 because VCF is 1-based
                record.info.push_back({.id = "END", .value = mate1.position + 1});
                sv_length = insert_size;
                sv_length_iGenVar = sv_length;
                sv_type = "INS";
            }
            // The SVLEN is neither too short nor too long than specified by the user.
            if (std::abs(sv_length) >= args.min_var_length &&
                std::abs(sv_length) <= args.max_var_length)
            {
                record.info.push_back({.id = "SVLEN", .value = sv_length});
                record.info.push_back({.id = "iGenVar_SVLEN", .value = sv_length_iGenVar});
                record.info.push_back({.id = "SVTYPE", .value = sv_type});
                found_SV = true;
            }
        }
    }
}

void find_and_output_variants(std::map<std::string, int32_t> & references_lengths,
                              std::vector<Cluster> const & clusters,
                              std::set<Junction> const & snp_indels,
                              cmd_arguments const & args,
                              std::filesystem::path const & output_file_path)
{
    bio::io::var::header hdr{};
    write_header(references_lengths, args.vcf_sample_name, hdr);

    bio::io::var::record<> record{};
    size_t amount_SVs = 0;
    bool found_SV = false;

    // Sets whether the standard C++ streams are synchronized to the standard C streams after each input/output operation.
    std::ios::sync_with_stdio(false);

    auto writer
        = output_file_path.empty() ? bio::io::var::writer{std::cout, bio::io::vcf{}} : bio::io::var::writer{output_file_path};

    writer.set_header(hdr);
    for (size_t i = 0; i < clusters.size(); ++i)
    {
        // ignore low quality SVs
        if (clusters[i].get_cluster_size() >= args.min_qual)
        {
            write_record(clusters[i], args, found_SV, record);
            if (found_SV)
            {
                writer.push_back(record);
                ++amount_SVs;
            }
        }
        found_SV = false;
    }

    // SNP/indel
    // Create instance of the modified record type (later, we use the default instance from above).
    bio::io::var::record<> rec{};

    size_t cnt = 0;
    for (Junction const & junction : snp_indels)
    {
        bool ins = junction.get_deleted_sequence().empty();
        bool del = junction.get_inserted_sequence().empty();
        rec.chrom = junction.get_mate1().seq_name;
        rec.pos = junction.get_mate1().position + 1; // Increment position by 1 because VCF is 1-based
        rec.id = seqan3::detail::to_string("igenvar_", ins ? "ins" : del ? "del" : "snp", "_", cnt++);
        rec.ref = seqan3::ranges::to<std::vector>(junction.get_deleted_sequence() | seqan3::views::to_char | bio::views::char_to<bio::alphabet::dna5>);
        rec.alt = {seqan3::detail::to_string(junction.get_inserted_sequence())};
        rec.qual = roundf(junction.get_quality() * 100) / 100.F; // round 2 digits
        rec.filter = {"PASS"};
        rec.genotypes = {};
        rec.genotypes.push_back({ .id = "GT", .value = std::vector{"./."s}});
        rec.info = {};
        writer.push_back(rec);
    }

    seqan3::debug_stream << "Detected " << amount_SVs << " SVs and " << snp_indels.size() << " SNPs/Indels.\n";
}
