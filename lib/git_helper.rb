# Helper methods used to retrieve information from a Grit repository needed for the view.
class GitHelper
  MAX_SEARCH_DEPTH = 1_000

  # A list of commits matching any one of the given authors in reverse chronological order.
  def self.commits_by_authors(repo, authors, count)
    # TODO(philc): We should use Grit's paging API here.
    commits = repo.commits("master", MAX_SEARCH_DEPTH)
    commits_by_author = []
    commits.each do |commit|
      if authors.find { |author| author_search_matches?(author, commit) }
        commits_by_author.push(commit)
        break if commits_by_author.size >= count
      end
    end
    commits_by_author
  end

  def self.author_search_matches?(author_search, commit)
    # tig seems to do some fuzzy matching here on the commit's author when you search by author.
    # For instance, "phil" matches "Phil Crosby <phil.crosby@gmail.com>".
    commit.author.email.downcase.index(author_search) == 0 ||
    commit.author.to_s.downcase.index(author_search) == 0
  end

  def self.get_tagged_commit_diffs(commit)

  end

  def self.apply_diff(data, diff)
    data_lines = data.split("\n")
    tagged_lines = []
    orig_line, diff_line = 0, 0
    chunks = tag_diff(diff)

    chunks.each do |chunk|
      if (chunk[:orig_line] > orig_line)
        tagged_lines += data_lines[ orig_line..chunk[:orig_line] ].map do |data|
          diff_line += 1
          orig_line += 1
          { :tag => :same, :data => data, :orig_line => orig_line, :diff_line => diff_line }
        end
      end
      tagged_lines += chunk[:tagged_lines]
      orig_line += chunk[:orig_length]
      diff_line += chunk[:diff_length]
    end
    if orig_line <= data_lines.count
      tagged_lines += data_lines[orig_line..data_lines.count].map do |data|
        diff_line += 1
        orig_line += 1
        { :tag => :same, :data => data, :orig_line => orig_line, :diff_line => diff_line }
      end
    end
    tagged_lines
  end

  def self.tag_diff(diff)
    diff_lines = diff_lines = diff.split("\n")
    chunks = []
    chunk = nil
    orig_line = 0
    diff_line = 0

    diff_lines.each do |line|
      match = /^@@ \-(\d+),(\d+) \+(\d+),(\d+) @@$/.match(line)
      if (match)
        orig_line = Integer(match[1])
        diff_line = Integer(match[3])
        chunk = { :orig_line => orig_line, :orig_length => Integer(match[2]),
                          :diff_line => diff_line, :diff_length => Integer(match[4]), :tagged_lines => [] }
        chunks << chunk
      elsif (chunk)
        #normal line after the first @@ line (eg: '-<div class="commitSection">')
        case line[0]
          when " "
            tag = :same
            diff_line += 1
            orig_line += 1
          when "+"
            tag = :added
            diff_line += 1
          when "-"
            tag = :removed
            orig_line += 1
        end
        chunk[:tagged_lines] << { :tag => tag, :data => line[1..-1],
                                  :orig_line => tag == :added ? "" : orig_line,
                                  :diff_line => tag == :removed ? "" : diff_line}
      end
    end
    chunks
  end
end
