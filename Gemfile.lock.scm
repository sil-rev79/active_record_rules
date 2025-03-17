(use-modules
  (guix-ruby gems)
  (gnu packages ruby)
  (guix build-system ruby)
  (guix download)
  (guix git-download)
  (guix packages)
  (ice-9 match))
(lambda* (#:key (ruby ruby) (groups '(default)) (gem-transformers %default-gem-transformers))
  (define ruby--actioncable
    (gem
      (transformers gem-transformers)
      (name "ruby--actioncable")
      (version "6.1.7.6")
      (propagated-inputs
        (list ruby--actionpack ruby--activesupport ruby--nio4r ruby--websocket-driver))
      (source
        (origin
          (method url-fetch)
          (uri (rubygems-uri "actioncable" version))
          (sha256 (base32 "1fdbks9byqqlkd6glj6lkz5f1z6948hh8fhv9x5pzqciralmz142"))))
      (arguments (list #:ruby ruby #:tests? #f))))
  (define ruby--actionmailbox
    (gem
      (transformers gem-transformers)
      (name "ruby--actionmailbox")
      (version "6.1.7.6")
      (propagated-inputs
        (list
          ruby--actionpack
          ruby--activejob
          ruby--activerecord
          ruby--activestorage
          ruby--activesupport
          ruby--mail))
      (source
        (origin
          (method url-fetch)
          (uri (rubygems-uri "actionmailbox" version))
          (sha256 (base32 "1rfya6qgsl14cm9l2w7h7lg4znsyg3gqiskhqr8wn76sh0x2hln0"))))
      (arguments (list #:ruby ruby #:tests? #f))))
  (define ruby--actionmailer
    (gem
      (transformers gem-transformers)
      (name "ruby--actionmailer")
      (version "6.1.7.6")
      (propagated-inputs
        (list
          ruby--actionpack
          ruby--actionview
          ruby--activejob
          ruby--activesupport
          ruby--mail
          ruby--rails-dom-testing))
      (source
        (origin
          (method url-fetch)
          (uri (rubygems-uri "actionmailer" version))
          (sha256 (base32 "0jr9jpf542svzqz8x68s08jnf30shxrrh7rq1a0s7jia5a5zx3qd"))))
      (arguments (list #:ruby ruby #:tests? #f))))
  (define ruby--actionpack
    (gem
      (transformers gem-transformers)
      (name "ruby--actionpack")
      (version "6.1.7.6")
      (propagated-inputs
        (list
          ruby--actionview
          ruby--activesupport
          ruby--rack
          ruby--rack-test
          ruby--rails-dom-testing
          ruby--rails-html-sanitizer))
      (source
        (origin
          (method url-fetch)
          (uri (rubygems-uri "actionpack" version))
          (sha256 (base32 "0vf6ncs647psa9p23d2108zgmlf0pr7gcjr080yg5yf68gyhs53k"))))
      (arguments (list #:ruby ruby #:tests? #f))))
  (define ruby--actiontext
    (gem
      (transformers gem-transformers)
      (name "ruby--actiontext")
      (version "6.1.7.6")
      (propagated-inputs
        (list
          ruby--actionpack
          ruby--activerecord
          ruby--activestorage
          ruby--activesupport
          ruby--nokogiri))
      (source
        (origin
          (method url-fetch)
          (uri (rubygems-uri "actiontext" version))
          (sha256 (base32 "1i8s3v6m8q3y17c40l6d3k2vs1mdqr0y1lfm7i6dfbj2y673lk9r"))))
      (arguments (list #:ruby ruby #:tests? #f))))
  (define ruby--actionview
    (gem
      (transformers gem-transformers)
      (name "ruby--actionview")
      (version "6.1.7.6")
      (propagated-inputs
        (list
          ruby--activesupport
          ruby--builder
          ruby--erubi
          ruby--rails-dom-testing
          ruby--rails-html-sanitizer))
      (source
        (origin
          (method url-fetch)
          (uri (rubygems-uri "actionview" version))
          (sha256 (base32 "1s4c1n5lv31sc7w4w74xz8gzyq3sann00bm4l7lxgy3vgi2wqkid"))))
      (arguments (list #:ruby ruby #:tests? #f))))
  (define ruby--activejob
    (gem
      (transformers gem-transformers)
      (name "ruby--activejob")
      (version "6.1.7.6")
      (propagated-inputs (list ruby--activesupport ruby--globalid))
      (source
        (origin
          (method url-fetch)
          (uri (rubygems-uri "activejob" version))
          (sha256 (base32 "1641003plszig5ybhrqy90fv43l1vcai5h35qmhh9j12byk5hp26"))))
      (arguments (list #:ruby ruby #:tests? #f))))
  (define ruby--activemodel
    (gem
      (transformers gem-transformers)
      (name "ruby--activemodel")
      (version "6.1.7.6")
      (propagated-inputs (list ruby--activesupport))
      (source
        (origin
          (method url-fetch)
          (uri (rubygems-uri "activemodel" version))
          (sha256 (base32 "148szdj5jlnfpv3nmy8cby8rxgpdvs43f3rzqby1f7a0l2knd3va"))))
      (arguments (list #:ruby ruby #:tests? #f))))
  (define ruby--activerecord
    (gem
      (transformers gem-transformers)
      (name "ruby--activerecord")
      (version "6.1.7.6")
      (propagated-inputs (list ruby--activemodel ruby--activesupport))
      (source
        (origin
          (method url-fetch)
          (uri (rubygems-uri "activerecord" version))
          (sha256 (base32 "0n7hg582ajdncilfk1kkw8qfdchymp2gqgkad1znlhlmclihsafr"))))
      (arguments (list #:ruby ruby #:tests? #f))))
  (define ruby--activestorage
    (gem
      (transformers gem-transformers)
      (name "ruby--activestorage")
      (version "6.1.7.6")
      (propagated-inputs
        (list
          ruby--actionpack
          ruby--activejob
          ruby--activerecord
          ruby--activesupport
          ruby--marcel
          ruby--mini-mime))
      (source
        (origin
          (method url-fetch)
          (uri (rubygems-uri "activestorage" version))
          (sha256 (base32 "16pylwnqsbvq2wxhl7k1rnravbr3dgpjmnj0psz5gijgkydd52yc"))))
      (arguments (list #:ruby ruby #:tests? #f))))
  (define ruby--activesupport
    (gem
      (transformers gem-transformers)
      (name "ruby--activesupport")
      (version "6.1.7.6")
      (propagated-inputs
        (list ruby--concurrent-ruby ruby--i18n ruby--minitest ruby--tzinfo ruby--zeitwerk))
      (source
        (origin
          (method url-fetch)
          (uri (rubygems-uri "activesupport" version))
          (sha256 (base32 "1nhrdih0rk46i0s6x7nqhbypmj1hf23zl5gfl9xasb6k4r2a1dxk"))))
      (arguments (list #:ruby ruby #:tests? #f))))
  (define ruby--ast
    (gem
      (transformers gem-transformers)
      (name "ruby--ast")
      (version "2.4.2")
      (propagated-inputs (list))
      (source
        (origin
          (method url-fetch)
          (uri (rubygems-uri "ast" version))
          (sha256 (base32 "04nc8x27hlzlrr5c2gn7mar4vdr0apw5xg22wp6m8dx3wqr04a0y"))))
      (arguments (list #:ruby ruby #:tests? #f))))
  (define ruby--builder
    (gem
      (transformers gem-transformers)
      (name "ruby--builder")
      (version "3.2.4")
      (propagated-inputs (list))
      (source
        (origin
          (method url-fetch)
          (uri (rubygems-uri "builder" version))
          (sha256 (base32 "045wzckxpwcqzrjr353cxnyaxgf0qg22jh00dcx7z38cys5g1jlr"))))
      (arguments (list #:ruby ruby #:tests? #f))))
  (define ruby--concurrent-ruby
    (gem
      (transformers gem-transformers)
      (name "ruby--concurrent-ruby")
      (version "1.2.2")
      (propagated-inputs (list))
      (source
        (origin
          (method url-fetch)
          (uri (rubygems-uri "concurrent-ruby" version))
          (sha256 (base32 "0krcwb6mn0iklajwngwsg850nk8k9b35dhmc2qkbdqvmifdi2y9q"))))
      (arguments (list #:ruby ruby #:tests? #f))))
  (define ruby--crass
    (gem
      (transformers gem-transformers)
      (name "ruby--crass")
      (version "1.0.6")
      (propagated-inputs (list))
      (source
        (origin
          (method url-fetch)
          (uri (rubygems-uri "crass" version))
          (sha256 (base32 "0pfl5c0pyqaparxaqxi6s4gfl21bdldwiawrc0aknyvflli60lfw"))))
      (arguments (list #:ruby ruby #:tests? #f))))
  (define ruby--date
    (gem
      (transformers gem-transformers)
      (name "ruby--date")
      (version "3.3.4")
      (propagated-inputs (list))
      (source
        (origin
          (method url-fetch)
          (uri (rubygems-uri "date" version))
          (sha256 (base32 "149jknsq999gnhy865n33fkk22s0r447k76x9pmcnnwldfv2q7wp"))))
      (arguments (list #:ruby ruby #:tests? #f))))
  (define ruby--diff-lcs
    (gem
      (transformers gem-transformers)
      (name "ruby--diff-lcs")
      (version "1.5.0")
      (propagated-inputs (list))
      (source
        (origin
          (method url-fetch)
          (uri (rubygems-uri "diff-lcs" version))
          (sha256 (base32 "0rwvjahnp7cpmracd8x732rjgnilqv2sx7d1gfrysslc3h039fa9"))))
      (arguments (list #:ruby ruby #:tests? #f))))
  (define ruby--erubi
    (gem
      (transformers gem-transformers)
      (name "ruby--erubi")
      (version "1.12.0")
      (propagated-inputs (list))
      (source
        (origin
          (method url-fetch)
          (uri (rubygems-uri "erubi" version))
          (sha256 (base32 "08s75vs9cxlc4r1q2bjg4br8g9wc5lc5x5vl0vv4zq5ivxsdpgi7"))))
      (arguments (list #:ruby ruby #:tests? #f))))
  (define ruby--globalid
    (gem
      (transformers gem-transformers)
      (name "ruby--globalid")
      (version "1.2.1")
      (propagated-inputs (list ruby--activesupport))
      (source
        (origin
          (method url-fetch)
          (uri (rubygems-uri "globalid" version))
          (sha256 (base32 "1sbw6b66r7cwdx3jhs46s4lr991969hvigkjpbdl7y3i31qpdgvh"))))
      (arguments (list #:ruby ruby #:tests? #f))))
  (define ruby--i18n
    (gem
      (transformers gem-transformers)
      (name "ruby--i18n")
      (version "1.14.1")
      (propagated-inputs (list ruby--concurrent-ruby))
      (source
        (origin
          (method url-fetch)
          (uri (rubygems-uri "i18n" version))
          (sha256 (base32 "0qaamqsh5f3szhcakkak8ikxlzxqnv49n2p7504hcz2l0f4nj0wx"))))
      (arguments (list #:ruby ruby #:tests? #f))))
  (define ruby--json
    (gem
      (transformers gem-transformers)
      (name "ruby--json")
      (version "2.7.0")
      (propagated-inputs (list))
      (source
        (origin
          (method url-fetch)
          (uri (rubygems-uri "json" version))
          (sha256 (base32 "0wi7g6c8q0v1kahwp38mv8d526p1n2ddsr79ajx84idvih0c601i"))))
      (arguments (list #:ruby ruby #:tests? #f))))
  (define ruby--language-server-protocol
    (gem
      (transformers gem-transformers)
      (name "ruby--language_server-protocol")
      (version "3.17.0.3")
      (propagated-inputs (list))
      (source
        (origin
          (method url-fetch)
          (uri (rubygems-uri "language_server-protocol" version))
          (sha256 (base32 "0gvb1j8xsqxms9mww01rmdl78zkd72zgxaap56bhv8j45z05hp1x"))))
      (arguments (list #:ruby ruby #:tests? #f))))
  (define ruby--loofah
    (gem
      (transformers gem-transformers)
      (name "ruby--loofah")
      (version "2.22.0")
      (propagated-inputs (list ruby--crass ruby--nokogiri))
      (source
        (origin
          (method url-fetch)
          (uri (rubygems-uri "loofah" version))
          (sha256 (base32 "1zkjqf37v2d7s11176cb35cl83wls5gm3adnfkn2zcc61h3nxmqh"))))
      (arguments (list #:ruby ruby #:tests? #f))))
  (define ruby--mail
    (gem
      (transformers gem-transformers)
      (name "ruby--mail")
      (version "2.8.1")
      (propagated-inputs (list ruby--mini-mime ruby--net-imap ruby--net-pop ruby--net-smtp))
      (source
        (origin
          (method url-fetch)
          (uri (rubygems-uri "mail" version))
          (sha256 (base32 "1bf9pysw1jfgynv692hhaycfxa8ckay1gjw5hz3madrbrynryfzc"))))
      (arguments (list #:ruby ruby #:tests? #f))))
  (define ruby--marcel
    (gem
      (transformers gem-transformers)
      (name "ruby--marcel")
      (version "1.0.2")
      (propagated-inputs (list))
      (source
        (origin
          (method url-fetch)
          (uri (rubygems-uri "marcel" version))
          (sha256 (base32 "0kky3yiwagsk8gfbzn3mvl2fxlh3b39v6nawzm4wpjs6xxvvc4x0"))))
      (arguments (list #:ruby ruby #:tests? #f))))
  (define ruby--method-source
    (gem
      (transformers gem-transformers)
      (name "ruby--method_source")
      (version "1.0.0")
      (propagated-inputs (list))
      (source
        (origin
          (method url-fetch)
          (uri (rubygems-uri "method_source" version))
          (sha256 (base32 "1pnyh44qycnf9mzi1j6fywd5fkskv3x7nmsqrrws0rjn5dd4ayfp"))))
      (arguments (list #:ruby ruby #:tests? #f))))
  (define ruby--mini-mime
    (gem
      (transformers gem-transformers)
      (name "ruby--mini_mime")
      (version "1.1.5")
      (propagated-inputs (list))
      (source
        (origin
          (method url-fetch)
          (uri (rubygems-uri "mini_mime" version))
          (sha256 (base32 "1vycif7pjzkr29mfk4dlqv3disc5dn0va04lkwajlpr1wkibg0c6"))))
      (arguments (list #:ruby ruby #:tests? #f))))
  (define ruby--minitest
    (gem
      (transformers gem-transformers)
      (name "ruby--minitest")
      (version "5.20.0")
      (propagated-inputs (list))
      (source
        (origin
          (method url-fetch)
          (uri (rubygems-uri "minitest" version))
          (sha256 (base32 "0bkmfi9mb49m0fkdhl2g38i3xxa02d411gg0m8x0gvbwfmmg5ym3"))))
      (arguments (list #:ruby ruby #:tests? #f))))
  (define ruby--net-imap
    (gem
      (transformers gem-transformers)
      (name "ruby--net-imap")
      (version "0.4.7")
      (propagated-inputs (list ruby--date ruby--net-protocol))
      (source
        (origin
          (method url-fetch)
          (uri (rubygems-uri "net-imap" version))
          (sha256 (base32 "0541lfqaz46h8s3fks11vsd1iqzmgjjw3c0jp9agg92zblwj0axs"))))
      (arguments (list #:ruby ruby #:tests? #f))))
  (define ruby--net-pop
    (gem
      (transformers gem-transformers)
      (name "ruby--net-pop")
      (version "0.1.2")
      (propagated-inputs (list ruby--net-protocol))
      (source
        (origin
          (method url-fetch)
          (uri (rubygems-uri "net-pop" version))
          (sha256 (base32 "1wyz41jd4zpjn0v1xsf9j778qx1vfrl24yc20cpmph8k42c4x2w4"))))
      (arguments (list #:ruby ruby #:tests? #f))))
  (define ruby--net-protocol
    (gem
      (transformers gem-transformers)
      (name "ruby--net-protocol")
      (version "0.2.2")
      (propagated-inputs (list ruby--timeout))
      (source
        (origin
          (method url-fetch)
          (uri (rubygems-uri "net-protocol" version))
          (sha256 (base32 "1a32l4x73hz200cm587bc29q8q9az278syw3x6fkc9d1lv5y0wxa"))))
      (arguments (list #:ruby ruby #:tests? #f))))
  (define ruby--net-smtp
    (gem
      (transformers gem-transformers)
      (name "ruby--net-smtp")
      (version "0.4.0")
      (propagated-inputs (list ruby--net-protocol))
      (source
        (origin
          (method url-fetch)
          (uri (rubygems-uri "net-smtp" version))
          (sha256 (base32 "1rx3758w0bmbr21s2nsc6llflsrnp50fwdnly3ixra4v53gbhzid"))))
      (arguments (list #:ruby ruby #:tests? #f))))
  (define ruby--nio4r
    (gem
      (transformers gem-transformers)
      (name "ruby--nio4r")
      (version "2.7.0")
      (propagated-inputs (list))
      (source
        (origin
          (method url-fetch)
          (uri (rubygems-uri "nio4r" version))
          (sha256 (base32 "0xkjz56qc7hl7zy7i7bhiyw5pl85wwjsa4p70rj6s958xj2sd1lm"))))
      (arguments (list #:ruby ruby #:tests? #f))))
  (define ruby--nokogiri
    (gem
      (transformers gem-transformers)
      (name "ruby--nokogiri")
      (version "1.15.5")
      (propagated-inputs
        (or
          (match (%current-system) ("x86_64-linux" (list ruby--racc)))
          (error "No supported system found for ~a@~a" "ruby--nokogiri" "1.15.5")))
      (source
        (or
          (match
            (%current-system)
            ("x86_64-linux"
             (origin
               (method url-fetch)
               (uri (list "https://rubygems.org/gems/nokogiri-1.15.5-x86_64-linux.gem"))
               (sha256 (base32 "1pvajkp9bajkfvk4iv5crz34x6gxjc9cr6f6ibq1bp2mq4y4bnf5")))))
          (error "No supported system found for ~a@~a" "ruby--nokogiri" "1.15.5")))
      (arguments (list #:ruby ruby #:tests? #f))))
  (define ruby--parallel
    (gem
      (transformers gem-transformers)
      (name "ruby--parallel")
      (version "1.23.0")
      (propagated-inputs (list))
      (source
        (origin
          (method url-fetch)
          (uri (rubygems-uri "parallel" version))
          (sha256 (base32 "0jcc512l38c0c163ni3jgskvq1vc3mr8ly5pvjijzwvfml9lf597"))))
      (arguments (list #:ruby ruby #:tests? #f))))
  (define ruby--parser
    (gem
      (transformers gem-transformers)
      (name "ruby--parser")
      (version "3.2.2.4")
      (propagated-inputs (list ruby--ast ruby--racc))
      (source
        (origin
          (method url-fetch)
          (uri (rubygems-uri "parser" version))
          (sha256 (base32 "0r69dbh6h6j4d54isany2ir4ni4gf2ysvk3k44awi6amz18nggpd"))))
      (arguments (list #:ruby ruby #:tests? #f))))
  (define ruby--parslet
    (gem
      (transformers gem-transformers)
      (name "ruby--parslet")
      (version "2.0.0")
      (propagated-inputs (list))
      (source
        (origin
          (method url-fetch)
          (uri (rubygems-uri "parslet" version))
          (sha256 (base32 "01pnw6ymz6nynklqvqxs4bcai25kcvnd5x4id9z3vd1rbmlk0lfl"))))
      (arguments (list #:ruby ruby #:tests? #f))))
  (define ruby--properb
    (gem
      (transformers gem-transformers)
      (name "ruby--properb")
      (version "0.0.1")
      (propagated-inputs (list ruby--rspec))
      (source
        (origin
          (method git-fetch)
          (uri
            (git-reference
              (url "https://git.sr.ht/~czan/properb")
              (commit "99b01e5b2ab17f2f34760390d030e8be81295882")))
          (sha256 (base32 "0i19hnjm0cqg7sb6g8asfl4mfyi7xrlsjmlgqjdj77gl93alm359"))))
      (native-search-paths
        (list
          (search-path-specification
            (variable "GEM_HOME")
            (separator #f)
            (files (list "lib/ruby/vendor_ruby")))
          (search-path-specification
            (variable "BUNDLE_CACHE_PATH")
            (separator #f)
            (files (list "lib/ruby/vendor_ruby/bundler")))))
      (arguments
        (list
          #:ruby ruby
          #:tests? #f
          #:phases
          '(modify-phases %standard-phases
             (add-after 'install 'install-git-sources
               (lambda* (#:key outputs #:allow-other-keys)
                 (let ((base (string-append (assoc-ref outputs "out") "/lib/ruby/vendor_ruby")))
                   (mkdir-p (string-append base "/bundler/gems/properb-99b01e5b2ab1"))
                   (copy-recursively
                     (string-append base "/gems/properb-0.0.1")
                     (string-append base "/bundler/gems/properb-99b01e5b2ab1"))
                   (copy-file
                     (string-append base "/specifications/properb-0.0.1.gemspec")
                     (string-append
                       base
                       "/bundler/gems/properb-99b01e5b2ab1/properb-0.0.1.gemspec"))))))))))
  (define ruby--racc
    (gem
      (transformers gem-transformers)
      (name "ruby--racc")
      (version "1.7.3")
      (propagated-inputs (list))
      (source
        (origin
          (method url-fetch)
          (uri (rubygems-uri "racc" version))
          (sha256 (base32 "01b9662zd2x9bp4rdjfid07h09zxj7kvn7f5fghbqhzc625ap1dp"))))
      (arguments (list #:ruby ruby #:tests? #f))))
  (define ruby--rack
    (gem
      (transformers gem-transformers)
      (name "ruby--rack")
      (version "2.2.8")
      (propagated-inputs (list))
      (source
        (origin
          (method url-fetch)
          (uri (rubygems-uri "rack" version))
          (sha256 (base32 "15rdwbyk71c9nxvd527bvb8jxkcys8r3dj3vqra5b3sa63qs30vv"))))
      (arguments (list #:ruby ruby #:tests? #f))))
  (define ruby--rack-test
    (gem
      (transformers gem-transformers)
      (name "ruby--rack-test")
      (version "2.1.0")
      (propagated-inputs (list ruby--rack))
      (source
        (origin
          (method url-fetch)
          (uri (rubygems-uri "rack-test" version))
          (sha256 (base32 "1ysx29gk9k14a14zsp5a8czys140wacvp91fja8xcja0j1hzqq8c"))))
      (arguments (list #:ruby ruby #:tests? #f))))
  (define ruby--rails
    (gem
      (transformers gem-transformers)
      (name "ruby--rails")
      (version "6.1.7.6")
      (propagated-inputs
        (list
          ruby--actioncable
          ruby--actionmailbox
          ruby--actionmailer
          ruby--actionpack
          ruby--actiontext
          ruby--actionview
          ruby--activejob
          ruby--activemodel
          ruby--activerecord
          ruby--activestorage
          ruby--activesupport
          ruby--railties
          ruby--sprockets-rails))
      (source
        (origin
          (method url-fetch)
          (uri (rubygems-uri "rails" version))
          (sha256 (base32 "0gf5dqabzd0mf0q39a07kf0smdm2cv2z5swl3zr4cz50yb85zz3l"))))
      (arguments (list #:ruby ruby #:tests? #f))))
  (define ruby--rails-dom-testing
    (gem
      (transformers gem-transformers)
      (name "ruby--rails-dom-testing")
      (version "2.2.0")
      (propagated-inputs (list ruby--activesupport ruby--minitest ruby--nokogiri))
      (source
        (origin
          (method url-fetch)
          (uri (rubygems-uri "rails-dom-testing" version))
          (sha256 (base32 "0fx9dx1ag0s1lr6lfr34lbx5i1bvn3bhyf3w3mx6h7yz90p725g5"))))
      (arguments (list #:ruby ruby #:tests? #f))))
  (define ruby--rails-html-sanitizer
    (gem
      (transformers gem-transformers)
      (name "ruby--rails-html-sanitizer")
      (version "1.6.0")
      (propagated-inputs (list ruby--loofah ruby--nokogiri))
      (source
        (origin
          (method url-fetch)
          (uri (rubygems-uri "rails-html-sanitizer" version))
          (sha256 (base32 "1pm4z853nyz1bhhqr7fzl44alnx4bjachcr6rh6qjj375sfz3sc6"))))
      (arguments (list #:ruby ruby #:tests? #f))))
  (define ruby--railties
    (gem
      (transformers gem-transformers)
      (name "ruby--railties")
      (version "6.1.7.6")
      (propagated-inputs
        (list ruby--actionpack ruby--activesupport ruby--method-source ruby--rake ruby--thor))
      (source
        (origin
          (method url-fetch)
          (uri (rubygems-uri "railties" version))
          (sha256 (base32 "1vq4ahyg9hraixxmmwwypdnpcylpvznvdxhj4xa23xk45wzbl3h7"))))
      (arguments (list #:ruby ruby #:tests? #f))))
  (define ruby--rainbow
    (gem
      (transformers gem-transformers)
      (name "ruby--rainbow")
      (version "3.1.1")
      (propagated-inputs (list))
      (source
        (origin
          (method url-fetch)
          (uri (rubygems-uri "rainbow" version))
          (sha256 (base32 "0smwg4mii0fm38pyb5fddbmrdpifwv22zv3d3px2xx497am93503"))))
      (arguments (list #:ruby ruby #:tests? #f))))
  (define ruby--rake
    (gem
      (transformers gem-transformers)
      (name "ruby--rake")
      (version "13.1.0")
      (propagated-inputs (list))
      (source
        (origin
          (method url-fetch)
          (uri (rubygems-uri "rake" version))
          (sha256 (base32 "1ilr853hawi09626axx0mps4rkkmxcs54mapz9jnqvpnlwd3wsmy"))))
      (arguments (list #:ruby ruby #:tests? #f))))
  (define ruby--regexp-parser
    (gem
      (transformers gem-transformers)
      (name "ruby--regexp_parser")
      (version "2.8.2")
      (propagated-inputs (list))
      (source
        (origin
          (method url-fetch)
          (uri (rubygems-uri "regexp_parser" version))
          (sha256 (base32 "1d9a5s3qrjdy50ll2s32gg3qmf10ryp3v2nr5k718kvfadp50ray"))))
      (arguments (list #:ruby ruby #:tests? #f))))
  (define ruby--rexml
    (gem
      (transformers gem-transformers)
      (name "ruby--rexml")
      (version "3.2.6")
      (propagated-inputs (list))
      (source
        (origin
          (method url-fetch)
          (uri (rubygems-uri "rexml" version))
          (sha256 (base32 "05i8518ay14kjbma550mv0jm8a6di8yp5phzrd8rj44z9qnrlrp0"))))
      (arguments (list #:ruby ruby #:tests? #f))))
  (define ruby--rspec
    (gem
      (transformers gem-transformers)
      (name "ruby--rspec")
      (version "3.12.0")
      (propagated-inputs (list ruby--rspec-core ruby--rspec-expectations ruby--rspec-mocks))
      (source
        (origin
          (method url-fetch)
          (uri (rubygems-uri "rspec" version))
          (sha256 (base32 "171rc90vcgjl8p1bdrqa92ymrj8a87qf6w20x05xq29mljcigi6c"))))
      (arguments (list #:ruby ruby #:tests? #f))))
  (define ruby--rspec-core
    (gem
      (transformers gem-transformers)
      (name "ruby--rspec-core")
      (version "3.12.2")
      (propagated-inputs (list ruby--rspec-support))
      (source
        (origin
          (method url-fetch)
          (uri (rubygems-uri "rspec-core" version))
          (sha256 (base32 "0l95bnjxdabrn79hwdhn2q1n7mn26pj7y1w5660v5qi81x458nqm"))))
      (arguments (list #:ruby ruby #:tests? #f))))
  (define ruby--rspec-expectations
    (gem
      (transformers gem-transformers)
      (name "ruby--rspec-expectations")
      (version "3.12.3")
      (propagated-inputs (list ruby--diff-lcs ruby--rspec-support))
      (source
        (origin
          (method url-fetch)
          (uri (rubygems-uri "rspec-expectations" version))
          (sha256 (base32 "05j44jfqlv7j2rpxb5vqzf9hfv7w8ba46wwgxwcwd8p0wzi1hg89"))))
      (arguments (list #:ruby ruby #:tests? #f))))
  (define ruby--rspec-mocks
    (gem
      (transformers gem-transformers)
      (name "ruby--rspec-mocks")
      (version "3.12.6")
      (propagated-inputs (list ruby--diff-lcs ruby--rspec-support))
      (source
        (origin
          (method url-fetch)
          (uri (rubygems-uri "rspec-mocks" version))
          (sha256 (base32 "1gq7gviwpck7fhp4y5ibljljvxgjklza18j62qf6zkm2icaa8lfy"))))
      (arguments (list #:ruby ruby #:tests? #f))))
  (define ruby--rspec-support
    (gem
      (transformers gem-transformers)
      (name "ruby--rspec-support")
      (version "3.12.1")
      (propagated-inputs (list))
      (source
        (origin
          (method url-fetch)
          (uri (rubygems-uri "rspec-support" version))
          (sha256 (base32 "1ky86j3ksi26ng9ybd7j0qsdf1lpr8mzrmn98yy9gzv801fvhsgr"))))
      (arguments (list #:ruby ruby #:tests? #f))))
  (define ruby--rubocop
    (gem
      (transformers gem-transformers)
      (name "ruby--rubocop")
      (version "1.57.2")
      (propagated-inputs
        (list
          ruby--json
          ruby--language-server-protocol
          ruby--parallel
          ruby--parser
          ruby--rainbow
          ruby--regexp-parser
          ruby--rexml
          ruby--rubocop-ast
          ruby--ruby-progressbar
          ruby--unicode-display-width))
      (source
        (origin
          (method url-fetch)
          (uri (rubygems-uri "rubocop" version))
          (sha256 (base32 "06qnp5zs233j4f59yyqrg8al6hr9n4a7vcdg3p31v0np8bz9srwg"))))
      (arguments (list #:ruby ruby #:tests? #f))))
  (define ruby--rubocop-ast
    (gem
      (transformers gem-transformers)
      (name "ruby--rubocop-ast")
      (version "1.30.0")
      (propagated-inputs (list ruby--parser))
      (source
        (origin
          (method url-fetch)
          (uri (rubygems-uri "rubocop-ast" version))
          (sha256 (base32 "1cs9cc5p9q70valk4na3lki4xs88b52486p2v46yx3q1n5969bgs"))))
      (arguments (list #:ruby ruby #:tests? #f))))
  (define ruby--rubocop-capybara
    (gem
      (transformers gem-transformers)
      (name "ruby--rubocop-capybara")
      (version "2.19.0")
      (propagated-inputs (list ruby--rubocop))
      (source
        (origin
          (method url-fetch)
          (uri (rubygems-uri "rubocop-capybara" version))
          (sha256 (base32 "1jwwi5a05947q9zsk6i599zxn657hdphbmmbbpx17qsv307rwcps"))))
      (arguments (list #:ruby ruby #:tests? #f))))
  (define ruby--rubocop-rspec
    (gem
      (transformers gem-transformers)
      (name "ruby--rubocop-rspec")
      (version "2.19.0")
      (propagated-inputs (list ruby--rubocop ruby--rubocop-capybara))
      (source
        (origin
          (method url-fetch)
          (uri (rubygems-uri "rubocop-rspec" version))
          (sha256 (base32 "1k8yh0nzlz0g8igmj5smnxq71qmi2b005nkl25wkpjkwvzn2wfdx"))))
      (arguments (list #:ruby ruby #:tests? #f))))
  (define ruby--ruby-progressbar
    (gem
      (transformers gem-transformers)
      (name "ruby--ruby-progressbar")
      (version "1.13.0")
      (propagated-inputs (list))
      (source
        (origin
          (method url-fetch)
          (uri (rubygems-uri "ruby-progressbar" version))
          (sha256 (base32 "0cwvyb7j47m7wihpfaq7rc47zwwx9k4v7iqd9s1xch5nm53rrz40"))))
      (arguments (list #:ruby ruby #:tests? #f))))
  (define ruby--sprockets
    (gem
      (transformers gem-transformers)
      (name "ruby--sprockets")
      (version "4.2.1")
      (propagated-inputs (list ruby--concurrent-ruby ruby--rack))
      (source
        (origin
          (method url-fetch)
          (uri (rubygems-uri "sprockets" version))
          (sha256 (base32 "15rzfzd9dca4v0mr0bbhsbwhygl0k9l24iqqlx0fijig5zfi66wm"))))
      (arguments (list #:ruby ruby #:tests? #f))))
  (define ruby--sprockets-rails
    (gem
      (transformers gem-transformers)
      (name "ruby--sprockets-rails")
      (version "3.4.2")
      (propagated-inputs (list ruby--actionpack ruby--activesupport ruby--sprockets))
      (source
        (origin
          (method url-fetch)
          (uri (rubygems-uri "sprockets-rails" version))
          (sha256 (base32 "1b9i14qb27zs56hlcc2hf139l0ghbqnjpmfi0054dxycaxvk5min"))))
      (arguments (list #:ruby ruby #:tests? #f))))
  (define ruby--sqlite3
    (gem
      (transformers gem-transformers)
      (name "ruby--sqlite3")
      (version "1.6.9")
      (propagated-inputs
        (or
          (match (%current-system) ("x86_64-linux" (list)))
          (error "No supported system found for ~a@~a" "ruby--sqlite3" "1.6.9")))
      (source
        (or
          (match
            (%current-system)
            ("x86_64-linux"
             (origin
               (method url-fetch)
               (uri (list "https://rubygems.org/gems/sqlite3-1.6.9-x86_64-linux.gem"))
               (sha256 (base32 "18nihkhiy6sjf5csfgjv88ji7xvjscgffxsipih4m5jy896jsk4j")))))
          (error "No supported system found for ~a@~a" "ruby--sqlite3" "1.6.9")))
      (arguments (list #:ruby ruby #:tests? #f))))
  (define ruby--thor
    (gem
      (transformers gem-transformers)
      (name "ruby--thor")
      (version "1.3.0")
      (propagated-inputs (list))
      (source
        (origin
          (method url-fetch)
          (uri (rubygems-uri "thor" version))
          (sha256 (base32 "1hx77jxkrwi66yvs10wfxqa8s25ds25ywgrrf66acm9nbfg7zp0s"))))
      (arguments (list #:ruby ruby #:tests? #f))))
  (define ruby--timeout
    (gem
      (transformers gem-transformers)
      (name "ruby--timeout")
      (version "0.4.1")
      (propagated-inputs (list))
      (source
        (origin
          (method url-fetch)
          (uri (rubygems-uri "timeout" version))
          (sha256 (base32 "16mvvsmx90023wrhf8dxc1lpqh0m8alk65shb7xcya6a9gflw7vg"))))
      (arguments (list #:ruby ruby #:tests? #f))))
  (define ruby--tzinfo
    (gem
      (transformers gem-transformers)
      (name "ruby--tzinfo")
      (version "2.0.6")
      (propagated-inputs (list ruby--concurrent-ruby))
      (source
        (origin
          (method url-fetch)
          (uri (rubygems-uri "tzinfo" version))
          (sha256 (base32 "16w2g84dzaf3z13gxyzlzbf748kylk5bdgg3n1ipvkvvqy685bwd"))))
      (arguments (list #:ruby ruby #:tests? #f))))
  (define ruby--unicode-display-width
    (gem
      (transformers gem-transformers)
      (name "ruby--unicode-display_width")
      (version "2.5.0")
      (propagated-inputs (list))
      (source
        (origin
          (method url-fetch)
          (uri (rubygems-uri "unicode-display_width" version))
          (sha256 (base32 "1d0azx233nags5jx3fqyr23qa2rhgzbhv8pxp46dgbg1mpf82xky"))))
      (arguments (list #:ruby ruby #:tests? #f))))
  (define ruby--websocket-driver
    (gem
      (transformers gem-transformers)
      (name "ruby--websocket-driver")
      (version "0.7.6")
      (propagated-inputs (list ruby--websocket-extensions))
      (source
        (origin
          (method url-fetch)
          (uri (rubygems-uri "websocket-driver" version))
          (sha256 (base32 "1nyh873w4lvahcl8kzbjfca26656d5c6z3md4sbqg5y1gfz0157n"))))
      (arguments (list #:ruby ruby #:tests? #f))))
  (define ruby--websocket-extensions
    (gem
      (transformers gem-transformers)
      (name "ruby--websocket-extensions")
      (version "0.1.5")
      (propagated-inputs (list))
      (source
        (origin
          (method url-fetch)
          (uri (rubygems-uri "websocket-extensions" version))
          (sha256 (base32 "0hc2g9qps8lmhibl5baa91b4qx8wqw872rgwagml78ydj8qacsqw"))))
      (arguments (list #:ruby ruby #:tests? #f))))
  (define ruby--zeitwerk
    (gem
      (transformers gem-transformers)
      (name "ruby--zeitwerk")
      (version "2.6.12")
      (propagated-inputs (list))
      (source
        (origin
          (method url-fetch)
          (uri (rubygems-uri "zeitwerk" version))
          (sha256 (base32 "1gir0if4nryl1jhwi28669gjwhxb7gzrm1fcc8xzsch3bnbi47jn"))))
      (arguments (list #:ruby ruby #:tests? #f))))
  (append
    (list ruby--activerecord ruby--parslet)
    (if (member 'default groups) (list) (list))
    (if (member 'test groups)
      (list
        ruby--rake
        ruby--rubocop
        ruby--rubocop-rspec
        ruby--rspec
        ruby--rails
        ruby--sqlite3
        ruby--properb)
      (list))))
