#!/usr/bin/ruby
# I427 Fall 2015, Assignment 4
#   Code authors: [Aaron]
#   Based on code from previous assignments
#   based on skeleton code by D Crandall

=begin

URL: http://cgi.soic.indiana.edu/~aarschwa/banana.html

Report

Much of the code used here is similar to Assignment 3.  The only added feature
is the TFIDF scoring.  For this assignment, rather than use the invindex
generated from my Assignment 3, I decided to use the invindex provided since it
added a nice feature: the number of documents that word appears in.
I used that feature to my advantage and will change my own code to be able to
produce the same feature for the final project so that ir may run faster.

read_data
-------------
I used the read_data that was provided in the forums but added a little code
to the encode segment to better format the titles.  The code I added replaces
any symbols unknown to UTF-8 with a space.

tfidf
-------------
This function builds a hash that stores the scores for each document from the
hitlist generated from find_hitList.  It loops through each keyword and finds
the df and tf values for each document according to the tfidf algorithm.  The 
df value follows the inverse log form of idf and substitutes the number of 
documents in the keyword's inverse index for the df value.  The tf value 
follows the normalized form of ntf and uses the document's word count in the
inverse index as the numerator and the total number of words in the document 
as the denominator.  These values are then multiplied to find the tfidf score.

=end

require 'fast-stemmer'

# This function writes out a hash or an array (list) to a file.
#  You can modify this function if you want, but it should already work as-is.
# 
# write_data("file1",my_hash)
# 
def write_data(filename, data)
  file = File.open(filename, "w")
  file.puts(data)
  file.close
end

# This function reads in a hash or an array (list) from a file produced by write_file().
#  You can modify this function if you want, but it should already work as-is.
# 
# my_list=read_data("file1")
# my_hash=read_data("file2")
def read_data(file_name)
  file = File.open(file_name,"r")
  object = eval(file.gets)
  file.close()
  return object
end

# load stopwords to process query terms
def load_stopwords_file(file)
  f = File.open(file, "r")
  stopwordH = {}
  f.each_line do |stopword|
    stopwordH[stopword] = 0
  end
    return stopwordH
end

def find_hitList(mode, queries, invindex)
# or mode
  hitList = []
  count = 0
  if mode  == 'or'
    for term in queries
      if invindex.member? term
        for page in invindex[term][1]
          unless hitList.include? page[0]
            hitList.push(page[0])
          end
          count += 1
        end
      end
    end
  end

# and mode
  if mode  == 'and'
    hitSet = []
    anyEmpty = false
    for term in queries
      if invindex.member? term
        for page in invindex[term][1]
          hitSet.push(page[0])
          count += 1
        end
        hitList.push(hitSet)
        hitSet = []
      end
      unless invindex.member? term
        anyEmpty = true
      end
    end
    if anyEmpty
      hitList = []
  else
      hitList = hitList.inject { |a,b| a&b}
    end
  end

# most mode
  if mode == 'most'
    hitHash = {}
    for term in queries
      if invindex.member? term
        for page in invindex[term][1]
          if hitHash.member? page[0]
            hitHash[page[0]] += 1
          else
            hitHash[page[0]] = 1
            count += 1
          end
        end
      end
    end
    for key in hitHash
      if key[1].to_i >= queries.length / 2.0
        hitList.push(key[0])
      end
    end
  end
  return [hitList,count]
end

def tfidf(queries, hitList, docindex, invindex)
  hitScores = {}
  for doc in hitList
    hitScores[doc] = 0.0
    score = 0.0
    for query in queries
      if invindex.member? query
        idf = 1.0 / (1.0 + Math.log10(invindex[query][0].to_f))
        ntf = invindex[query][1][doc].to_f / docindex[doc][0].to_f
        score += ntf*idf
      end
    end
    hitScores[doc] += score
  end
  return hitScores.sort_by{|k,v| v}.reverse
end

#################################################
# Main program. We expect the user to run the program like this:
#
#   ./retrieve.rb kw1 kw2 kw3 .. kwn
#

######### NOTE
# Part 1 says "The program should look up the pages containing the set of most of a set of query term"
# so the mode is by default set to 'most' and is not required when giving arguments.
# The 'expected' run is set above.

# check that the user gave us correct command line parameters
abort "Command line should have at least 1 parameter." if ARGV.size<1

mode = 'most'
keyword_list = ARGV[0..ARGV.size]

# read in the index file produced by the crawler from Assignment 2 (mapping html to a list of word count, title, and url).
docindex=read_data("doc.dat")

# read in the inverted index produced by the indexer. 
invindex=read_data("invindex.dat")

stops = load_stopwords_file("stop.txt")

queryTerms = []

# process the query terms - removing stop words, downcasing, and stemming
# store the processed query terms in a list
for term in keyword_list
  unless stops.member? term.downcase
    queryTerms.push(term.downcase.stem)
  end
end

hitList = find_hitList(mode, queryTerms, invindex)
tfidf = tfidf(queryTerms, hitList[0], docindex, invindex)


tfidf.first(25).each do |key, value|
  print "\n"
  print docindex[key][1].split.join(" ")
  print "\n"
  print docindex[key][2]
  print "\n"
  print "Relevance: #{value}"
  print "\n"
end

print "\n"
print "Total number of documents searched: #{hitList[1]}"
print "\n"
print "Total number of documents found: #{hitList[0].length}"
print "\n"
