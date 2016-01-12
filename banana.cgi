#!/l/ruby-2.2.2/bin/ruby

require 'cgi'
require 'fast-stemmer'

cgi = CGI.new("html4")

#Had problems loading the methods from retrieve2.rb so I just pasted them into here.

#had lots of problems with encoding, used reference page below
#http://stackoverflow.com/questions/2982677/ruby-1-9-invalid-byte-sequence-in-utf-8
def read_data(file_name)
  file = File.open(file_name,"r")
  object = eval(file.gets.untaint.encode('UTF-8', :invalid => :replace, :replace  => '').gsub('\n', ""))
  file.close()
  return object
end

def load_stopwords_file(file)
  f = File.open(file, "r")
  stopwordH = {}
  f.each_line do |stopword|
    stopwordH[stopword.chomp] = 0
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


def tfidf(queries, hitList, invindex, docindex)
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

mode = 'most'

# fetch keywords from input text
keyword_list = cgi['query'].split(" ")

# initialize stuff
docindex = read_data("/u/aarschwa/cgi-pub/a4/doc.dat")
invindex = read_data("/u/aarschwa/cgi-pub/a4/invindex.dat")
stops = load_stopwords_file("/u/aarschwa/cgi-pub/a4/stop.txt")
queryTerms = []

# parse keywords
for term in keyword_list
  unless stops.member? term.downcase
    queryTerms.push(term.downcase.stem)
  end
end

# do the search
hitList = find_hitList(mode, queryTerms, invindex)
printbody = ""

if hitList[0].length > 0
  tfidf = tfidf(queryTerms, hitList[0], invindex, docindex)
  
  # construct string for cgi.body
  tfidf.first(25).each do |key,value|
    printbody = printbody + cgi.li + cgi.a(docindex[key][2]) {docindex[key][1].split.join(" ")}
    printbody = printbody + cgi.li + docindex[key][2] + cgi.li
    #printbody = printbody + cgi.li + "#{value}" + cgi.li
  end
end

# back button
printbody += cgi.li + cgi.a("http://cgi.soic.indiana.edu/~aarschwa/banana.html") {"Back to Search"}


# reference for changing background color in cgi using css
# http://compgroups.net/comp.lang.ruby/cgi-scripts-and-external-css/753728
cgi.out{
  cgi.html{
    cgi.head{cgi.title{"Banana Search"}+"<link rel=\"stylesheet\"type=\"text/css\" href=\"banana.css\">" } + 
    cgi.body{"\n"+cgi.h1{"Search results for: " + cgi['query']} +  printbody}
  }
}
