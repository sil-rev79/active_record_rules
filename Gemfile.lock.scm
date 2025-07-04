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
      (version "7.2.2.1")
      (propagated-inputs
        (append
          (list ruby--actionpack)
          (list ruby--activesupport)
          (list ruby--nio4r)
          (list ruby--websocket-driver)
          (list ruby--zeitwerk)))
      (source
        (origin
          (method url-fetch)
          (uri (rubygems-uri "actioncable" version))
          (sha256 (base32 "1d7z3fqanmzr6d99idvm2qj6lil2pxn5haxz7kb6f1x8fm88hfsv"))))
      (arguments (list #:ruby ruby #:tests? #f))))
  (define ruby--actionmailbox
    (gem
      (transformers gem-transformers)
      (name "ruby--actionmailbox")
      (version "7.2.2.1")
      (propagated-inputs
        (append
          (list ruby--actionpack)
          (list ruby--activejob)
          (list ruby--activerecord)
          (list ruby--activestorage)
          (list ruby--activesupport)
          (list ruby--mail)))
      (source
        (origin
          (method url-fetch)
          (uri (rubygems-uri "actionmailbox" version))
          (sha256 (base32 "098f12d19q64d0svzgz73w23mv2y3zmccryybp3hfi8gab14fsl9"))))
      (arguments (list #:ruby ruby #:tests? #f))))
  (define ruby--actionmailer
    (gem
      (transformers gem-transformers)
      (name "ruby--actionmailer")
      (version "7.2.2.1")
      (propagated-inputs
        (append
          (list ruby--actionpack)
          (list ruby--actionview)
          (list ruby--activejob)
          (list ruby--activesupport)
          (list ruby--mail)
          (list ruby--rails-dom-testing)))
      (source
        (origin
          (method url-fetch)
          (uri (rubygems-uri "actionmailer" version))
          (sha256 (base32 "07xjqxmwif57wxz28ch10c3c2261ydv1x56vsiidg2icqciyaamh"))))
      (arguments (list #:ruby ruby #:tests? #f))))
  (define ruby--actionpack
    (gem
      (transformers gem-transformers)
      (name "ruby--actionpack")
      (version "7.2.2.1")
      (propagated-inputs
        (append
          (list ruby--actionview)
          (list ruby--activesupport)
          (list ruby--nokogiri)
          (list ruby--racc)
          (list ruby--rack)
          (list ruby--rack-session)
          (list ruby--rack-test)
          (list ruby--rails-dom-testing)
          (list ruby--rails-html-sanitizer)
          (list ruby--useragent)))
      (source
        (origin
          (method url-fetch)
          (uri (rubygems-uri "actionpack" version))
          (sha256 (base32 "0d7pq6fsf041fvskzmqm12xcgk5m9d5fa6kbs1lsbmfbgc51dchp"))))
      (arguments (list #:ruby ruby #:tests? #f))))
  (define ruby--actiontext
    (gem
      (transformers gem-transformers)
      (name "ruby--actiontext")
      (version "7.2.2.1")
      (propagated-inputs
        (append
          (list ruby--actionpack)
          (list ruby--activerecord)
          (list ruby--activestorage)
          (list ruby--activesupport)
          (list ruby--globalid)
          (list ruby--nokogiri)))
      (source
        (origin
          (method url-fetch)
          (uri (rubygems-uri "actiontext" version))
          (sha256 (base32 "1mphlcvnfba3gd1sydcrr2i7brfwlcbxjmwjpybvcx363bjcwsgk"))))
      (arguments (list #:ruby ruby #:tests? #f))))
  (define ruby--actionview
    (gem
      (transformers gem-transformers)
      (name "ruby--actionview")
      (version "7.2.2.1")
      (propagated-inputs
        (append
          (list ruby--activesupport)
          (list ruby--builder)
          (list ruby--erubi)
          (list ruby--rails-dom-testing)
          (list ruby--rails-html-sanitizer)))
      (source
        (origin
          (method url-fetch)
          (uri (rubygems-uri "actionview" version))
          (sha256 (base32 "19arngl1nshasvbh90gzc23z1vpid2xzg3043grbmcfqyc68iz39"))))
      (arguments (list #:ruby ruby #:tests? #f))))
  (define ruby--activejob
    (gem
      (transformers gem-transformers)
      (name "ruby--activejob")
      (version "7.2.2.1")
      (propagated-inputs (append (list ruby--activesupport) (list ruby--globalid)))
      (source
        (origin
          (method url-fetch)
          (uri (rubygems-uri "activejob" version))
          (sha256 (base32 "0nryqb19i3frxhanykf6lmrw0rb09863z114gi7sm55kff2mmygj"))))
      (arguments (list #:ruby ruby #:tests? #f))))
  (define ruby--activemodel
    (gem
      (transformers gem-transformers)
      (name "ruby--activemodel")
      (version "7.2.2.1")
      (propagated-inputs (append (list ruby--activesupport)))
      (source
        (origin
          (method url-fetch)
          (uri (rubygems-uri "activemodel" version))
          (sha256 (base32 "1bzxvccj8349slymls7navb5y14anglkkasphcd6gi72kqgqd643"))))
      (arguments (list #:ruby ruby #:tests? #f))))
  (define ruby--activerecord
    (gem
      (transformers gem-transformers)
      (name "ruby--activerecord")
      (version "7.2.2.1")
      (propagated-inputs
        (append (list ruby--activemodel) (list ruby--activesupport) (list ruby--timeout)))
      (source
        (origin
          (method url-fetch)
          (uri (rubygems-uri "activerecord" version))
          (sha256 (base32 "1fgscw775wj4l7f5pj274a984paz23zy0111giqkhl9dqdqiz8vr"))))
      (arguments (list #:ruby ruby #:tests? #f))))
  (define ruby--activestorage
    (gem
      (transformers gem-transformers)
      (name "ruby--activestorage")
      (version "7.2.2.1")
      (propagated-inputs
        (append
          (list ruby--actionpack)
          (list ruby--activejob)
          (list ruby--activerecord)
          (list ruby--activesupport)
          (list ruby--marcel)))
      (source
        (origin
          (method url-fetch)
          (uri (rubygems-uri "activestorage" version))
          (sha256 (base32 "0psjqn03irbfk79x57ylaaaj83pqqcwy8b4mwrp6bmnljkzkbv5l"))))
      (arguments (list #:ruby ruby #:tests? #f))))
  (define ruby--activesupport
    (gem
      (transformers gem-transformers)
      (name "ruby--activesupport")
      (version "7.2.2.1")
      (propagated-inputs
        (append
          (list ruby--base64)
          (list ruby--benchmark)
          (list ruby--bigdecimal)
          (list ruby--concurrent-ruby)
          (list ruby--connection-pool)
          (list ruby--drb)
          (list ruby--i18n)
          (list ruby--logger)
          (list ruby--minitest)
          (list ruby--securerandom)
          (list ruby--tzinfo)))
      (source
        (origin
          (method url-fetch)
          (uri (rubygems-uri "activesupport" version))
          (sha256 (base32 "1xa7hr4gp2p86ly6n1j2skyx8pfg6yi621kmnh7zhxr9m7wcnaw4"))))
      (arguments (list #:ruby ruby #:tests? #f))))
  (define ruby--ast
    (gem
      (transformers gem-transformers)
      (name "ruby--ast")
      (version "2.4.3")
      (propagated-inputs (append))
      (source
        (origin
          (method url-fetch)
          (uri (rubygems-uri "ast" version))
          (sha256 (base32 "10yknjyn0728gjn6b5syynvrvrwm66bhssbxq8mkhshxghaiailm"))))
      (arguments (list #:ruby ruby #:tests? #f))))
  (define ruby--base64
    (gem
      (transformers gem-transformers)
      (name "ruby--base64")
      (version "0.2.0")
      (propagated-inputs (append))
      (source
        (origin
          (method url-fetch)
          (uri (rubygems-uri "base64" version))
          (sha256 (base32 "01qml0yilb9basf7is2614skjp8384h2pycfx86cr8023arfj98g"))))
      (arguments (list #:ruby ruby #:tests? #f))))
  (define ruby--benchmark
    (gem
      (transformers gem-transformers)
      (name "ruby--benchmark")
      (version "0.4.0")
      (propagated-inputs (append))
      (source
        (origin
          (method url-fetch)
          (uri (rubygems-uri "benchmark" version))
          (sha256 (base32 "0jl71qcgamm96dzyqk695j24qszhcc7liw74qc83fpjljp2gh4hg"))))
      (arguments (list #:ruby ruby #:tests? #f))))
  (define ruby--bigdecimal
    (gem
      (transformers gem-transformers)
      (name "ruby--bigdecimal")
      (version "3.1.9")
      (propagated-inputs (append))
      (source
        (origin
          (method url-fetch)
          (uri (rubygems-uri "bigdecimal" version))
          (sha256 (base32 "1k6qzammv9r6b2cw3siasaik18i6wjc5m0gw5nfdc6jj64h79z1g"))))
      (arguments (list #:ruby ruby #:tests? #f))))
  (define ruby--builder
    (gem
      (transformers gem-transformers)
      (name "ruby--builder")
      (version "3.3.0")
      (propagated-inputs (append))
      (source
        (origin
          (method url-fetch)
          (uri (rubygems-uri "builder" version))
          (sha256 (base32 "0pw3r2lyagsxkm71bf44v5b74f7l9r7di22brbyji9fwz791hya9"))))
      (arguments (list #:ruby ruby #:tests? #f))))
  (define ruby--concurrent-ruby
    (gem
      (transformers gem-transformers)
      (name "ruby--concurrent-ruby")
      (version "1.3.5")
      (propagated-inputs (append))
      (source
        (origin
          (method url-fetch)
          (uri (rubygems-uri "concurrent-ruby" version))
          (sha256 (base32 "1ipbrgvf0pp6zxdk5ascp6i29aybz2bx9wdrlchjmpx6mhvkwfw1"))))
      (arguments (list #:ruby ruby #:tests? #f))))
  (define ruby--connection-pool
    (gem
      (transformers gem-transformers)
      (name "ruby--connection_pool")
      (version "2.5.0")
      (propagated-inputs (append))
      (source
        (origin
          (method url-fetch)
          (uri (rubygems-uri "connection_pool" version))
          (sha256 (base32 "1z7bag6zb2vwi7wp2bkdkmk7swkj6zfnbsnc949qq0wfsgw94fr3"))))
      (arguments (list #:ruby ruby #:tests? #f))))
  (define ruby--crass
    (gem
      (transformers gem-transformers)
      (name "ruby--crass")
      (version "1.0.6")
      (propagated-inputs (append))
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
      (version "3.4.1")
      (propagated-inputs (append))
      (source
        (origin
          (method url-fetch)
          (uri (rubygems-uri "date" version))
          (sha256 (base32 "0kz6mc4b9m49iaans6cbx031j9y7ldghpi5fzsdh0n3ixwa8w9mz"))))
      (arguments (list #:ruby ruby #:tests? #f))))
  (define ruby--diff-lcs
    (gem
      (transformers gem-transformers)
      (name "ruby--diff-lcs")
      (version "1.6.1")
      (propagated-inputs (append))
      (source
        (origin
          (method url-fetch)
          (uri (rubygems-uri "diff-lcs" version))
          (sha256 (base32 "1m3cv0ynmxq93axp6kiby9wihpsdj42y6s3j8bsf5a1p7qzsi98j"))))
      (arguments (list #:ruby ruby #:tests? #f))))
  (define ruby--docile
    (gem
      (transformers gem-transformers)
      (name "ruby--docile")
      (version "1.4.1")
      (propagated-inputs (append))
      (source
        (origin
          (method url-fetch)
          (uri (rubygems-uri "docile" version))
          (sha256 (base32 "07pj4z3h8wk4fgdn6s62vw1lwvhj0ac0x10vfbdkr9xzk7krn5cn"))))
      (arguments (list #:ruby ruby #:tests? #f))))
  (define ruby--drb
    (gem
      (transformers gem-transformers)
      (name "ruby--drb")
      (version "2.2.1")
      (propagated-inputs (append))
      (source
        (origin
          (method url-fetch)
          (uri (rubygems-uri "drb" version))
          (sha256 (base32 "0h5kbj9hvg5hb3c7l425zpds0vb42phvln2knab8nmazg2zp5m79"))))
      (arguments (list #:ruby ruby #:tests? #f))))
  (define ruby--erubi
    (gem
      (transformers gem-transformers)
      (name "ruby--erubi")
      (version "1.13.1")
      (propagated-inputs (append))
      (source
        (origin
          (method url-fetch)
          (uri (rubygems-uri "erubi" version))
          (sha256 (base32 "1naaxsqkv5b3vklab5sbb9sdpszrjzlfsbqpy7ncbnw510xi10m0"))))
      (arguments (list #:ruby ruby #:tests? #f))))
  (define ruby--globalid
    (gem
      (transformers gem-transformers)
      (name "ruby--globalid")
      (version "1.2.1")
      (propagated-inputs (append (list ruby--activesupport)))
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
      (version "1.14.7")
      (propagated-inputs (append (list ruby--concurrent-ruby)))
      (source
        (origin
          (method url-fetch)
          (uri (rubygems-uri "i18n" version))
          (sha256 (base32 "03sx3ahz1v5kbqjwxj48msw3maplpp2iyzs22l4jrzrqh4zmgfnf"))))
      (arguments (list #:ruby ruby #:tests? #f))))
  (define ruby--io-console
    (gem
      (transformers gem-transformers)
      (name "ruby--io-console")
      (version "0.8.0")
      (propagated-inputs (append))
      (source
        (origin
          (method url-fetch)
          (uri (rubygems-uri "io-console" version))
          (sha256 (base32 "18pgvl7lfjpichdfh1g50rpz0zpaqrpr52ybn9liv1v9pjn9ysnd"))))
      (arguments (list #:ruby ruby #:tests? #f))))
  (define ruby--irb
    (gem
      (transformers gem-transformers)
      (name "ruby--irb")
      (version "1.15.1")
      (propagated-inputs (append (list ruby--pp) (list ruby--rdoc) (list ruby--reline)))
      (source
        (origin
          (method url-fetch)
          (uri (rubygems-uri "irb" version))
          (sha256 (base32 "1478m97wiy6nwg6lnl0szy39p46acsvrhax552vsh1s2mi2sgg6r"))))
      (arguments (list #:ruby ruby #:tests? #f))))
  (define ruby--json
    (gem
      (transformers gem-transformers)
      (name "ruby--json")
      (version "2.10.2")
      (propagated-inputs (append))
      (source
        (origin
          (method url-fetch)
          (uri (rubygems-uri "json" version))
          (sha256 (base32 "01lbdaizhkxmrw4y8j3wpvsryvnvzmg0pfs56c52laq2jgdfmq1l"))))
      (arguments (list #:ruby ruby #:tests? #f))))
  (define ruby--language-server-protocol
    (gem
      (transformers gem-transformers)
      (name "ruby--language_server-protocol")
      (version "3.17.0.4")
      (propagated-inputs (append))
      (source
        (origin
          (method url-fetch)
          (uri (rubygems-uri "language_server-protocol" version))
          (sha256 (base32 "0scnz2fvdczdgadvjn0j9d49118aqm3hj66qh8sd2kv6g1j65164"))))
      (arguments (list #:ruby ruby #:tests? #f))))
  (define ruby--lint-roller
    (gem
      (transformers gem-transformers)
      (name "ruby--lint_roller")
      (version "1.1.0")
      (propagated-inputs (append))
      (source
        (origin
          (method url-fetch)
          (uri (rubygems-uri "lint_roller" version))
          (sha256 (base32 "11yc0d84hsnlvx8cpk4cbj6a4dz9pk0r1k29p0n1fz9acddq831c"))))
      (arguments (list #:ruby ruby #:tests? #f))))
  (define ruby--logger
    (gem
      (transformers gem-transformers)
      (name "ruby--logger")
      (version "1.7.0")
      (propagated-inputs (append))
      (source
        (origin
          (method url-fetch)
          (uri (rubygems-uri "logger" version))
          (sha256 (base32 "00q2zznygpbls8asz5knjvvj2brr3ghmqxgr83xnrdj4rk3xwvhr"))))
      (arguments (list #:ruby ruby #:tests? #f))))
  (define ruby--loofah
    (gem
      (transformers gem-transformers)
      (name "ruby--loofah")
      (version "2.24.0")
      (propagated-inputs (append (list ruby--crass) (list ruby--nokogiri)))
      (source
        (origin
          (method url-fetch)
          (uri (rubygems-uri "loofah" version))
          (sha256 (base32 "07pfa5kgl7k2hxlzzn89qna6bmiyrxlchgbzi0885frsi08agrk1"))))
      (arguments (list #:ruby ruby #:tests? #f))))
  (define ruby--mail
    (gem
      (transformers gem-transformers)
      (name "ruby--mail")
      (version "2.8.1")
      (propagated-inputs
        (append
          (list ruby--mini-mime)
          (list ruby--net-imap)
          (list ruby--net-pop)
          (list ruby--net-smtp)))
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
      (version "1.0.4")
      (propagated-inputs (append))
      (source
        (origin
          (method url-fetch)
          (uri (rubygems-uri "marcel" version))
          (sha256 (base32 "190n2mk8m1l708kr88fh6mip9sdsh339d2s6sgrik3sbnvz4jmhd"))))
      (arguments (list #:ruby ruby #:tests? #f))))
  (define ruby--mini-mime
    (gem
      (transformers gem-transformers)
      (name "ruby--mini_mime")
      (version "1.1.5")
      (propagated-inputs (append))
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
      (version "5.25.5")
      (propagated-inputs (append))
      (source
        (origin
          (method url-fetch)
          (uri (rubygems-uri "minitest" version))
          (sha256 (base32 "0mn7q9yzrwinvfvkyjiz548a4rmcwbmz2fn9nyzh4j1snin6q6rr"))))
      (arguments (list #:ruby ruby #:tests? #f))))
  (define ruby--net-imap
    (gem
      (transformers gem-transformers)
      (name "ruby--net-imap")
      (version "0.5.6")
      (propagated-inputs (append (list ruby--date) (list ruby--net-protocol)))
      (source
        (origin
          (method url-fetch)
          (uri (rubygems-uri "net-imap" version))
          (sha256 (base32 "1rgva7p9gvns2ndnqpw503mbd36i2skkggv0c0h192k8xr481phy"))))
      (arguments (list #:ruby ruby #:tests? #f))))
  (define ruby--net-pop
    (gem
      (transformers gem-transformers)
      (name "ruby--net-pop")
      (version "0.1.2")
      (propagated-inputs (append (list ruby--net-protocol)))
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
      (propagated-inputs (append (list ruby--timeout)))
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
      (version "0.5.1")
      (propagated-inputs (append (list ruby--net-protocol)))
      (source
        (origin
          (method url-fetch)
          (uri (rubygems-uri "net-smtp" version))
          (sha256 (base32 "0dh7nzjp0fiaqq1jz90nv4nxhc2w359d7c199gmzq965cfps15pd"))))
      (arguments (list #:ruby ruby #:tests? #f))))
  (define ruby--nio4r
    (gem
      (transformers gem-transformers)
      (name "ruby--nio4r")
      (version "2.7.4")
      (propagated-inputs (append))
      (source
        (origin
          (method url-fetch)
          (uri (rubygems-uri "nio4r" version))
          (sha256 (base32 "1a9www524fl1ykspznz54i0phfqya4x45hqaz67in9dvw1lfwpfr"))))
      (arguments (list #:ruby ruby #:tests? #f))))
  (define ruby--nokogiri
    (gem
      (transformers gem-transformers)
      (name "ruby--nokogiri")
      (version "1.18.6")
      (propagated-inputs
        (or
          (match (%current-system) ("x86_64-linux" (append (list ruby--racc))))
          (error "No supported system found for ~a@~a" "ruby--nokogiri" "1.18.6")))
      (source
        (or
          (match
            (%current-system)
            ("x86_64-linux"
             (origin
               (method url-fetch)
               (uri (list "https://rubygems.org/gems/nokogiri-1.18.6-x86_64-linux-gnu.gem"))
               (sha256 (base32 "0wbbqshp459xvhyf6pqjhm3c4316rw7qckzhdvvq07kfpav5s1nz")))))
          (error "No supported system found for ~a@~a" "ruby--nokogiri" "1.18.6")))
      (arguments (list #:ruby ruby #:tests? #f))))
  (define ruby--parallel
    (gem
      (transformers gem-transformers)
      (name "ruby--parallel")
      (version "1.26.3")
      (propagated-inputs (append))
      (source
        (origin
          (method url-fetch)
          (uri (rubygems-uri "parallel" version))
          (sha256 (base32 "1vy7sjs2pgz4i96v5yk9b7aafbffnvq7nn419fgvw55qlavsnsyq"))))
      (arguments (list #:ruby ruby #:tests? #f))))
  (define ruby--parser
    (gem
      (transformers gem-transformers)
      (name "ruby--parser")
      (version "3.3.7.4")
      (propagated-inputs (append (list ruby--ast) (list ruby--racc)))
      (source
        (origin
          (method url-fetch)
          (uri (rubygems-uri "parser" version))
          (sha256 (base32 "1awq9rswd3mj8sr5acp1ca6nbkk57zpw8388j7w163i8fhi2h9ib"))))
      (arguments (list #:ruby ruby #:tests? #f))))
  (define ruby--parslet
    (gem
      (transformers gem-transformers)
      (name "ruby--parslet")
      (version "2.0.0")
      (propagated-inputs (append))
      (source
        (origin
          (method url-fetch)
          (uri (rubygems-uri "parslet" version))
          (sha256 (base32 "01pnw6ymz6nynklqvqxs4bcai25kcvnd5x4id9z3vd1rbmlk0lfl"))))
      (arguments (list #:ruby ruby #:tests? #f))))
  (define ruby--pg
    (gem
      (transformers gem-transformers)
      (name "ruby--pg")
      (version "1.5.9")
      (propagated-inputs (append))
      (source
        (origin
          (method url-fetch)
          (uri (rubygems-uri "pg" version))
          (sha256 (base32 "1p2gqqrm895fzr9vi8d118zhql67bm8ydjvgqbq1crdnfggzn7kn"))))
      (arguments (list #:ruby ruby #:tests? #f))))
  (define ruby--pp
    (gem
      (transformers gem-transformers)
      (name "ruby--pp")
      (version "0.6.2")
      (propagated-inputs (append (list ruby--prettyprint)))
      (source
        (origin
          (method url-fetch)
          (uri (rubygems-uri "pp" version))
          (sha256 (base32 "1zxnfxjni0r9l2x42fyq0sqpnaf5nakjbap8irgik4kg1h9c6zll"))))
      (arguments (list #:ruby ruby #:tests? #f))))
  (define ruby--prettyprint
    (gem
      (transformers gem-transformers)
      (name "ruby--prettyprint")
      (version "0.2.0")
      (propagated-inputs (append))
      (source
        (origin
          (method url-fetch)
          (uri (rubygems-uri "prettyprint" version))
          (sha256 (base32 "14zicq3plqi217w6xahv7b8f7aj5kpxv1j1w98344ix9h5ay3j9b"))))
      (arguments (list #:ruby ruby #:tests? #f))))
  (define ruby--prism
    (gem
      (transformers gem-transformers)
      (name "ruby--prism")
      (version "1.4.0")
      (propagated-inputs (append))
      (source
        (origin
          (method url-fetch)
          (uri (rubygems-uri "prism" version))
          (sha256 (base32 "0gkhpdjib9zi9i27vd9djrxiwjia03cijmd6q8yj2q1ix403w3nw"))))
      (arguments (list #:ruby ruby #:tests? #f))))
  (define ruby--properb
    (gem
      (transformers gem-transformers)
      (name "ruby--properb")
      (version "0.0.1")
      (propagated-inputs (append (list ruby--rspec)))
      (source
        (origin
          (method git-fetch)
          (uri
            (git-reference
              (url "https://git.sr.ht/~czan/properb")
              (commit "48613358a0d352c05383eaa0fcf101b523822ef7")))
          (sha256 (base32 "13phh8kahi593rl9mxiha38n8pf9qr0im8h15gzgvgb6z1bsg5fw"))))
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
                   (mkdir-p (string-append base "/bundler/gems/properb-48613358a0d3"))
                   (copy-recursively
                     (string-append base "/gems/properb-0.0.1")
                     (string-append base "/bundler/gems/properb-48613358a0d3"))
                   (copy-file
                     (string-append base "/specifications/properb-0.0.1.gemspec")
                     (string-append
                       base
                       "/bundler/gems/properb-48613358a0d3/properb-0.0.1.gemspec"))))))))))
  (define ruby--psych
    (gem
      (transformers gem-transformers)
      (name "ruby--psych")
      (version "5.2.3")
      (propagated-inputs (append (list ruby--date) (list ruby--stringio)))
      (source
        (origin
          (method url-fetch)
          (uri (rubygems-uri "psych" version))
          (sha256 (base32 "1vjrx3yd596zzi42dcaq5xw7hil1921r769dlbz08iniaawlp9c4"))))
      (arguments (list #:ruby ruby #:tests? #f))))
  (define ruby--puma
    (gem
      (transformers gem-transformers)
      (name "ruby--puma")
      (version "6.6.0")
      (propagated-inputs (append (list ruby--nio4r)))
      (source
        (origin
          (method url-fetch)
          (uri (rubygems-uri "puma" version))
          (sha256 (base32 "11xd3207k5rl6bz0qxhcb3zcr941rhx7ig2f19gxxmdk7s3hcp7j"))))
      (arguments (list #:ruby ruby #:tests? #f))))
  (define ruby--racc
    (gem
      (transformers gem-transformers)
      (name "ruby--racc")
      (version "1.8.1")
      (propagated-inputs (append))
      (source
        (origin
          (method url-fetch)
          (uri (rubygems-uri "racc" version))
          (sha256 (base32 "0byn0c9nkahsl93y9ln5bysq4j31q8xkf2ws42swighxd4lnjzsa"))))
      (arguments (list #:ruby ruby #:tests? #f))))
  (define ruby--rack
    (gem
      (transformers gem-transformers)
      (name "ruby--rack")
      (version "3.1.12")
      (propagated-inputs (append))
      (source
        (origin
          (method url-fetch)
          (uri (rubygems-uri "rack" version))
          (sha256 (base32 "0h65a1f9gsqx2ryisdy4lrd9a9l8gdv65dcscw9ynwwjr1ak1n00"))))
      (arguments (list #:ruby ruby #:tests? #f))))
  (define ruby--rack-session
    (gem
      (transformers gem-transformers)
      (name "ruby--rack-session")
      (version "2.1.0")
      (propagated-inputs (append (list ruby--base64) (list ruby--rack)))
      (source
        (origin
          (method url-fetch)
          (uri (rubygems-uri "rack-session" version))
          (sha256 (base32 "1452c1bhh6fdnv17s1z65ajwh08axqnlmkhnr1qyyn2vacb3jz23"))))
      (arguments (list #:ruby ruby #:tests? #f))))
  (define ruby--rack-test
    (gem
      (transformers gem-transformers)
      (name "ruby--rack-test")
      (version "2.2.0")
      (propagated-inputs (append (list ruby--rack)))
      (source
        (origin
          (method url-fetch)
          (uri (rubygems-uri "rack-test" version))
          (sha256 (base32 "0qy4ylhcfdn65a5mz2hly7g9vl0g13p5a0rmm6sc0sih5ilkcnh0"))))
      (arguments (list #:ruby ruby #:tests? #f))))
  (define ruby--rackup
    (gem
      (transformers gem-transformers)
      (name "ruby--rackup")
      (version "2.2.1")
      (propagated-inputs (append (list ruby--rack)))
      (source
        (origin
          (method url-fetch)
          (uri (rubygems-uri "rackup" version))
          (sha256 (base32 "13brkq5xkj6lcdxj3f0k7v28hgrqhqxjlhd4y2vlicy5slgijdzp"))))
      (arguments (list #:ruby ruby #:tests? #f))))
  (define ruby--rails
    (gem
      (transformers gem-transformers)
      (name "ruby--rails")
      (version "7.2.2.1")
      (propagated-inputs
        (append
          (list ruby--actioncable)
          (list ruby--actionmailbox)
          (list ruby--actionmailer)
          (list ruby--actionpack)
          (list ruby--actiontext)
          (list ruby--actionview)
          (list ruby--activejob)
          (list ruby--activemodel)
          (list ruby--activerecord)
          (list ruby--activestorage)
          (list ruby--activesupport)
          (list ruby--railties)))
      (source
        (origin
          (method url-fetch)
          (uri (rubygems-uri "rails" version))
          (sha256 (base32 "0h5vr7wd15s4zlhrnrm97b1h5bjdlcd5lvh6x2sl6khgnh21dnxf"))))
      (arguments (list #:ruby ruby #:tests? #f))))
  (define ruby--rails-dom-testing
    (gem
      (transformers gem-transformers)
      (name "ruby--rails-dom-testing")
      (version "2.2.0")
      (propagated-inputs
        (append (list ruby--activesupport) (list ruby--minitest) (list ruby--nokogiri)))
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
      (version "1.6.2")
      (propagated-inputs (append (list ruby--loofah) (list ruby--nokogiri)))
      (source
        (origin
          (method url-fetch)
          (uri (rubygems-uri "rails-html-sanitizer" version))
          (sha256 (base32 "0q55i6mpad20m2x1lg5pkqfpbmmapk0sjsrvr1sqgnj2hb5f5z1m"))))
      (arguments (list #:ruby ruby #:tests? #f))))
  (define ruby--railties
    (gem
      (transformers gem-transformers)
      (name "ruby--railties")
      (version "7.2.2.1")
      (propagated-inputs
        (append
          (list ruby--actionpack)
          (list ruby--activesupport)
          (list ruby--irb)
          (list ruby--rackup)
          (list ruby--rake)
          (list ruby--thor)
          (list ruby--zeitwerk)))
      (source
        (origin
          (method url-fetch)
          (uri (rubygems-uri "railties" version))
          (sha256 (base32 "07zy8b88qxx493pc5sfkzvxqj3zcf363r1128n3hsvfx2vqipwg3"))))
      (arguments (list #:ruby ruby #:tests? #f))))
  (define ruby--rainbow
    (gem
      (transformers gem-transformers)
      (name "ruby--rainbow")
      (version "3.1.1")
      (propagated-inputs (append))
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
      (version "13.2.1")
      (propagated-inputs (append))
      (source
        (origin
          (method url-fetch)
          (uri (rubygems-uri "rake" version))
          (sha256 (base32 "17850wcwkgi30p7yqh60960ypn7yibacjjha0av78zaxwvd3ijs6"))))
      (arguments (list #:ruby ruby #:tests? #f))))
  (define ruby--rdoc
    (gem
      (transformers gem-transformers)
      (name "ruby--rdoc")
      (version "6.13.1")
      (propagated-inputs (append (list ruby--psych)))
      (source
        (origin
          (method url-fetch)
          (uri (rubygems-uri "rdoc" version))
          (sha256 (base32 "1xvjskc5xp5x4lgrkxqrn7n4rjzgbbjl9yx3ny74xjckjk4xm832"))))
      (arguments (list #:ruby ruby #:tests? #f))))
  (define ruby--regexp-parser
    (gem
      (transformers gem-transformers)
      (name "ruby--regexp_parser")
      (version "2.10.0")
      (propagated-inputs (append))
      (source
        (origin
          (method url-fetch)
          (uri (rubygems-uri "regexp_parser" version))
          (sha256 (base32 "0qccah61pjvzyyg6mrp27w27dlv6vxlbznzipxjcswl7x3fhsvyb"))))
      (arguments (list #:ruby ruby #:tests? #f))))
  (define ruby--reline
    (gem
      (transformers gem-transformers)
      (name "ruby--reline")
      (version "0.6.0")
      (propagated-inputs (append (list ruby--io-console)))
      (source
        (origin
          (method url-fetch)
          (uri (rubygems-uri "reline" version))
          (sha256 (base32 "1lirwlw59apc8m1wjk85y2xidiv0fkxjn6f7p84yqmmyvish6qjp"))))
      (arguments (list #:ruby ruby #:tests? #f))))
  (define ruby--rspec
    (gem
      (transformers gem-transformers)
      (name "ruby--rspec")
      (version "3.13.0")
      (propagated-inputs
        (append (list ruby--rspec-core) (list ruby--rspec-expectations) (list ruby--rspec-mocks)))
      (source
        (origin
          (method url-fetch)
          (uri (rubygems-uri "rspec" version))
          (sha256 (base32 "14xrp8vq6i9zx37vh0yp4h9m0anx9paw200l1r5ad9fmq559346l"))))
      (arguments (list #:ruby ruby #:tests? #f))))
  (define ruby--rspec-core
    (gem
      (transformers gem-transformers)
      (name "ruby--rspec-core")
      (version "3.13.3")
      (propagated-inputs (append (list ruby--rspec-support)))
      (source
        (origin
          (method url-fetch)
          (uri (rubygems-uri "rspec-core" version))
          (sha256 (base32 "1r6zbis0hhbik1ck8kh58qb37d1qwij1x1d2fy4jxkzryh3na4r5"))))
      (arguments (list #:ruby ruby #:tests? #f))))
  (define ruby--rspec-expectations
    (gem
      (transformers gem-transformers)
      (name "ruby--rspec-expectations")
      (version "3.13.3")
      (propagated-inputs (append (list ruby--diff-lcs) (list ruby--rspec-support)))
      (source
        (origin
          (method url-fetch)
          (uri (rubygems-uri "rspec-expectations" version))
          (sha256 (base32 "0n3cyrhsa75x5wwvskrrqk56jbjgdi2q1zx0irllf0chkgsmlsqf"))))
      (arguments (list #:ruby ruby #:tests? #f))))
  (define ruby--rspec-mocks
    (gem
      (transformers gem-transformers)
      (name "ruby--rspec-mocks")
      (version "3.13.2")
      (propagated-inputs (append (list ruby--diff-lcs) (list ruby--rspec-support)))
      (source
        (origin
          (method url-fetch)
          (uri (rubygems-uri "rspec-mocks" version))
          (sha256 (base32 "1vxxkb2sf2b36d8ca2nq84kjf85fz4x7wqcvb8r6a5hfxxfk69r3"))))
      (arguments (list #:ruby ruby #:tests? #f))))
  (define ruby--rspec-support
    (gem
      (transformers gem-transformers)
      (name "ruby--rspec-support")
      (version "3.13.2")
      (propagated-inputs (append))
      (source
        (origin
          (method url-fetch)
          (uri (rubygems-uri "rspec-support" version))
          (sha256 (base32 "1v6v6xvxcpkrrsrv7v1xgf7sl0d71vcfz1cnrjflpf6r7x3a58yf"))))
      (arguments (list #:ruby ruby #:tests? #f))))
  (define ruby--rubocop
    (gem
      (transformers gem-transformers)
      (name "ruby--rubocop")
      (version "1.75.1")
      (propagated-inputs
        (append
          (list ruby--json)
          (list ruby--language-server-protocol)
          (list ruby--lint-roller)
          (list ruby--parallel)
          (list ruby--parser)
          (list ruby--rainbow)
          (list ruby--regexp-parser)
          (list ruby--rubocop-ast)
          (list ruby--ruby-progressbar)
          (list ruby--unicode-display-width)))
      (source
        (origin
          (method url-fetch)
          (uri (rubygems-uri "rubocop" version))
          (sha256 (base32 "0afwk8iq0bapp4acldyf35q094pbbdbzgxw42gnyclhbbg2h0af1"))))
      (arguments (list #:ruby ruby #:tests? #f))))
  (define ruby--rubocop-ast
    (gem
      (transformers gem-transformers)
      (name "ruby--rubocop-ast")
      (version "1.43.0")
      (propagated-inputs (append (list ruby--parser) (list ruby--prism)))
      (source
        (origin
          (method url-fetch)
          (uri (rubygems-uri "rubocop-ast" version))
          (sha256 (base32 "16mp7ppf3p516zs0iwbpqkn7fxs8iw12jargrc905qbc6fg69kcj"))))
      (arguments (list #:ruby ruby #:tests? #f))))
  (define ruby--rubocop-capybara
    (gem
      (transformers gem-transformers)
      (name "ruby--rubocop-capybara")
      (version "2.22.1")
      (propagated-inputs (append (list ruby--lint-roller) (list ruby--rubocop)))
      (source
        (origin
          (method url-fetch)
          (uri (rubygems-uri "rubocop-capybara" version))
          (sha256 (base32 "030wymq0jrblrdswl1lncj60dhcg5wszz6708qzsbziyyap8rn6f"))))
      (arguments (list #:ruby ruby #:tests? #f))))
  (define ruby--rubocop-factory-bot
    (gem
      (transformers gem-transformers)
      (name "ruby--rubocop-factory_bot")
      (version "2.27.1")
      (propagated-inputs (append (list ruby--lint-roller) (list ruby--rubocop)))
      (source
        (origin
          (method url-fetch)
          (uri (rubygems-uri "rubocop-factory_bot" version))
          (sha256 (base32 "1zkkhldrdacv4gn58dc591jxjnw5d767frzywm41i33p2rclnx4x"))))
      (arguments (list #:ruby ruby #:tests? #f))))
  (define ruby--rubocop-performance
    (gem
      (transformers gem-transformers)
      (name "ruby--rubocop-performance")
      (version "1.25.0")
      (propagated-inputs
        (append (list ruby--lint-roller) (list ruby--rubocop) (list ruby--rubocop-ast)))
      (source
        (origin
          (method url-fetch)
          (uri (rubygems-uri "rubocop-performance" version))
          (sha256 (base32 "1h9flnqk2f3llwf8g0mk0fvzzznfj7hsil3qg88m803pi9b06zbg"))))
      (arguments (list #:ruby ruby #:tests? #f))))
  (define ruby--rubocop-rails
    (gem
      (transformers gem-transformers)
      (name "ruby--rubocop-rails")
      (version "2.31.0")
      (propagated-inputs
        (append
          (list ruby--activesupport)
          (list ruby--lint-roller)
          (list ruby--rack)
          (list ruby--rubocop)
          (list ruby--rubocop-ast)))
      (source
        (origin
          (method url-fetch)
          (uri (rubygems-uri "rubocop-rails" version))
          (sha256 (base32 "1gajdiwcd1apsyg8k6vimsx9wkv169y9qm2hzih3x719fl86wivr"))))
      (arguments (list #:ruby ruby #:tests? #f))))
  (define ruby--rubocop-rails-omakase
    (gem
      (transformers gem-transformers)
      (name "ruby--rubocop-rails-omakase")
      (version "1.1.0")
      (propagated-inputs
        (append (list ruby--rubocop) (list ruby--rubocop-performance) (list ruby--rubocop-rails)))
      (source
        (origin
          (method url-fetch)
          (uri (rubygems-uri "rubocop-rails-omakase" version))
          (sha256 (base32 "178h17q6wfsxk8gzqk1ca6dw25cwmwc2dgdb34lxwljqxv43mxra"))))
      (arguments (list #:ruby ruby #:tests? #f))))
  (define ruby--rubocop-rspec
    (gem
      (transformers gem-transformers)
      (name "ruby--rubocop-rspec")
      (version "2.31.0")
      (propagated-inputs
        (append
          (list ruby--rubocop)
          (list ruby--rubocop-capybara)
          (list ruby--rubocop-factory-bot)
          (list ruby--rubocop-rspec-rails)))
      (source
        (origin
          (method url-fetch)
          (uri (rubygems-uri "rubocop-rspec" version))
          (sha256 (base32 "0wnnlfxmqcm1s1lb3hfa43pz829j9z9mznacwjncxqbqilw1kbib"))))
      (arguments (list #:ruby ruby #:tests? #f))))
  (define ruby--rubocop-rspec-rails
    (gem
      (transformers gem-transformers)
      (name "ruby--rubocop-rspec_rails")
      (version "2.29.1")
      (propagated-inputs (append (list ruby--rubocop)))
      (source
        (origin
          (method url-fetch)
          (uri (rubygems-uri "rubocop-rspec_rails" version))
          (sha256 (base32 "1r489726zdxmh44lqpdh6fh6nnzv63950kp1idnrnnnax6xmmsaa"))))
      (arguments (list #:ruby ruby #:tests? #f))))
  (define ruby--ruby-progressbar
    (gem
      (transformers gem-transformers)
      (name "ruby--ruby-progressbar")
      (version "1.13.0")
      (propagated-inputs (append))
      (source
        (origin
          (method url-fetch)
          (uri (rubygems-uri "ruby-progressbar" version))
          (sha256 (base32 "0cwvyb7j47m7wihpfaq7rc47zwwx9k4v7iqd9s1xch5nm53rrz40"))))
      (arguments (list #:ruby ruby #:tests? #f))))
  (define ruby--securerandom
    (gem
      (transformers gem-transformers)
      (name "ruby--securerandom")
      (version "0.4.1")
      (propagated-inputs (append))
      (source
        (origin
          (method url-fetch)
          (uri (rubygems-uri "securerandom" version))
          (sha256 (base32 "1cd0iriqfsf1z91qg271sm88xjnfd92b832z49p1nd542ka96lfc"))))
      (arguments (list #:ruby ruby #:tests? #f))))
  (define ruby--simplecov
    (gem
      (transformers gem-transformers)
      (name "ruby--simplecov")
      (version "0.22.0")
      (propagated-inputs
        (append
          (list ruby--docile)
          (list ruby--simplecov-html)
          (list ruby--simplecov-json-formatter)))
      (source
        (origin
          (method url-fetch)
          (uri (rubygems-uri "simplecov" version))
          (sha256 (base32 "198kcbrjxhhzca19yrdcd6jjj9sb51aaic3b0sc3pwjghg3j49py"))))
      (arguments (list #:ruby ruby #:tests? #f))))
  (define ruby--simplecov-html
    (gem
      (transformers gem-transformers)
      (name "ruby--simplecov-html")
      (version "0.13.1")
      (propagated-inputs (append))
      (source
        (origin
          (method url-fetch)
          (uri (rubygems-uri "simplecov-html" version))
          (sha256 (base32 "02zi3rwihp7rlnp9x18c9idnkx7x68w6jmxdhyc0xrhjwrz0pasx"))))
      (arguments (list #:ruby ruby #:tests? #f))))
  (define ruby--simplecov-json-formatter
    (gem
      (transformers gem-transformers)
      (name "ruby--simplecov_json_formatter")
      (version "0.1.4")
      (propagated-inputs (append))
      (source
        (origin
          (method url-fetch)
          (uri (rubygems-uri "simplecov_json_formatter" version))
          (sha256 (base32 "0a5l0733hj7sk51j81ykfmlk2vd5vaijlq9d5fn165yyx3xii52j"))))
      (arguments (list #:ruby ruby #:tests? #f))))
  (define ruby--sprockets
    (gem
      (transformers gem-transformers)
      (name "ruby--sprockets")
      (version "4.2.2")
      (propagated-inputs
        (append (list ruby--concurrent-ruby) (list ruby--logger) (list ruby--rack)))
      (source
        (origin
          (method url-fetch)
          (uri (rubygems-uri "sprockets" version))
          (sha256 (base32 "1car3fpzhn1l06x2zmanz2l4bj346mv3jcgpcd3p1262y54ml7kn"))))
      (arguments (list #:ruby ruby #:tests? #f))))
  (define ruby--sprockets-rails
    (gem
      (transformers gem-transformers)
      (name "ruby--sprockets-rails")
      (version "3.5.2")
      (propagated-inputs
        (append (list ruby--actionpack) (list ruby--activesupport) (list ruby--sprockets)))
      (source
        (origin
          (method url-fetch)
          (uri (rubygems-uri "sprockets-rails" version))
          (sha256 (base32 "17hiqkdpcjyyhlm997mgdcr45v35j5802m5a979i5jgqx5n8xs59"))))
      (arguments (list #:ruby ruby #:tests? #f))))
  (define ruby--sqlite3
    (gem
      (transformers gem-transformers)
      (name "ruby--sqlite3")
      (version "2.6.0")
      (propagated-inputs
        (or
          (match (%current-system) ("x86_64-linux" (append)))
          (error "No supported system found for ~a@~a" "ruby--sqlite3" "2.6.0")))
      (source
        (or
          (match
            (%current-system)
            ("x86_64-linux"
             (origin
               (method url-fetch)
               (uri (list "https://rubygems.org/gems/sqlite3-2.6.0-x86_64-linux-gnu.gem"))
               (sha256 (base32 "1l7jaj7ppynvbawzd8wzzxi8jb6fzlb9nlnl5lanbf0jwq5ranj1")))))
          (error "No supported system found for ~a@~a" "ruby--sqlite3" "2.6.0")))
      (arguments (list #:ruby ruby #:tests? #f))))
  (define ruby--stringio
    (gem
      (transformers gem-transformers)
      (name "ruby--stringio")
      (version "3.1.6")
      (propagated-inputs (append))
      (source
        (origin
          (method url-fetch)
          (uri (rubygems-uri "stringio" version))
          (sha256 (base32 "1xblh8332bivml93232hg8qr2rhflq9czvij1bgzrbap2rfljb19"))))
      (arguments (list #:ruby ruby #:tests? #f))))
  (define ruby--thor
    (gem
      (transformers gem-transformers)
      (name "ruby--thor")
      (version "1.3.2")
      (propagated-inputs (append))
      (source
        (origin
          (method url-fetch)
          (uri (rubygems-uri "thor" version))
          (sha256 (base32 "1nmymd86a0vb39pzj2cwv57avdrl6pl3lf5bsz58q594kqxjkw7f"))))
      (arguments (list #:ruby ruby #:tests? #f))))
  (define ruby--timeout
    (gem
      (transformers gem-transformers)
      (name "ruby--timeout")
      (version "0.4.3")
      (propagated-inputs (append))
      (source
        (origin
          (method url-fetch)
          (uri (rubygems-uri "timeout" version))
          (sha256 (base32 "03p31w5ghqfsbz5mcjzvwgkw3h9lbvbknqvrdliy8pxmn9wz02cm"))))
      (arguments (list #:ruby ruby #:tests? #f))))
  (define ruby--tzinfo
    (gem
      (transformers gem-transformers)
      (name "ruby--tzinfo")
      (version "2.0.6")
      (propagated-inputs (append (list ruby--concurrent-ruby)))
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
      (version "3.1.4")
      (propagated-inputs (append (list ruby--unicode-emoji)))
      (source
        (origin
          (method url-fetch)
          (uri (rubygems-uri "unicode-display_width" version))
          (sha256 (base32 "1has87asspm6m9wgqas8ghhhwyf2i1yqrqgrkv47xw7jq3qjmbwc"))))
      (arguments (list #:ruby ruby #:tests? #f))))
  (define ruby--unicode-emoji
    (gem
      (transformers gem-transformers)
      (name "ruby--unicode-emoji")
      (version "4.0.4")
      (propagated-inputs (append))
      (source
        (origin
          (method url-fetch)
          (uri (rubygems-uri "unicode-emoji" version))
          (sha256 (base32 "0ajk6rngypm3chvl6r0vwv36q1931fjqaqhjjya81rakygvlwb1c"))))
      (arguments (list #:ruby ruby #:tests? #f))))
  (define ruby--useragent
    (gem
      (transformers gem-transformers)
      (name "ruby--useragent")
      (version "0.16.11")
      (propagated-inputs (append))
      (source
        (origin
          (method url-fetch)
          (uri (rubygems-uri "useragent" version))
          (sha256 (base32 "0i1q2xdjam4d7gwwc35lfnz0wyyzvnca0zslcfxm9fabml9n83kh"))))
      (arguments (list #:ruby ruby #:tests? #f))))
  (define ruby--websocket-driver
    (gem
      (transformers gem-transformers)
      (name "ruby--websocket-driver")
      (version "0.7.7")
      (propagated-inputs (append (list ruby--base64) (list ruby--websocket-extensions)))
      (source
        (origin
          (method url-fetch)
          (uri (rubygems-uri "websocket-driver" version))
          (sha256 (base32 "1d26l4qn55ivzahbc7fwc4k4z3j7wzym05i9n77i4mslrpr9jv85"))))
      (arguments (list #:ruby ruby #:tests? #f))))
  (define ruby--websocket-extensions
    (gem
      (transformers gem-transformers)
      (name "ruby--websocket-extensions")
      (version "0.1.5")
      (propagated-inputs (append))
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
      (version "2.6.18")
      (propagated-inputs (append))
      (source
        (origin
          (method url-fetch)
          (uri (rubygems-uri "zeitwerk" version))
          (sha256 (base32 "10cpfdswql21vildiin0q7drg5zfzf2sahnk9hv3nyzzjqwj2bdx"))))
      (arguments (list #:ruby ruby #:tests? #f))))
  (append
    (if (member 'default groups)
      (append
        (append (list ruby--activerecord) (list ruby--parslet) (list ruby--rails))
        (list ruby--puma)
        (list ruby--sqlite3)
        (list ruby--sprockets-rails)
        (list ruby--rubocop-rails-omakase))
      (list))
    (if (member 'test groups)
      (append
        (list ruby--rake)
        (list ruby--rubocop)
        (list ruby--rubocop-rspec)
        (list ruby--rspec)
        (list ruby--rails)
        (list ruby--pg)
        (list ruby--properb)
        (list ruby--simplecov))
      (list))))
