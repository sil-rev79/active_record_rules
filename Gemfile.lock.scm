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
      (version "7.1.5.1")
      (propagated-inputs
        (list
          ruby--actionpack
          ruby--activesupport
          ruby--nio4r
          ruby--websocket-driver
          ruby--zeitwerk))
      (source
        (origin
          (method url-fetch)
          (uri (rubygems-uri "actioncable" version))
          (sha256 (base32 "03dai8z2dxb2cf29hp6md7bhysyipxvw2qnm2bj98yyrnaskfikn"))))
      (arguments (list #:ruby ruby #:tests? #f))))
  (define ruby--actionmailbox
    (gem
      (transformers gem-transformers)
      (name "ruby--actionmailbox")
      (version "7.1.5.1")
      (propagated-inputs
        (list
          ruby--actionpack
          ruby--activejob
          ruby--activerecord
          ruby--activestorage
          ruby--activesupport
          ruby--mail
          ruby--net-imap
          ruby--net-pop
          ruby--net-smtp))
      (source
        (origin
          (method url-fetch)
          (uri (rubygems-uri "actionmailbox" version))
          (sha256 (base32 "02inlpsmjz8rz159ljhzac1dvzq5k1pnmmx2pf4gmrj3zs4hbhn3"))))
      (arguments (list #:ruby ruby #:tests? #f))))
  (define ruby--actionmailer
    (gem
      (transformers gem-transformers)
      (name "ruby--actionmailer")
      (version "7.1.5.1")
      (propagated-inputs
        (list
          ruby--actionpack
          ruby--actionview
          ruby--activejob
          ruby--activesupport
          ruby--mail
          ruby--net-imap
          ruby--net-pop
          ruby--net-smtp
          ruby--rails-dom-testing))
      (source
        (origin
          (method url-fetch)
          (uri (rubygems-uri "actionmailer" version))
          (sha256 (base32 "0ncplhcrxldj6jvbaw9g8ik4cznjlf3lyfzgrwy0jfxjh3cdc4xj"))))
      (arguments (list #:ruby ruby #:tests? #f))))
  (define ruby--actionpack
    (gem
      (transformers gem-transformers)
      (name "ruby--actionpack")
      (version "7.1.5.1")
      (propagated-inputs
        (list
          ruby--actionview
          ruby--activesupport
          ruby--nokogiri
          ruby--racc
          ruby--rack
          ruby--rack-session
          ruby--rack-test
          ruby--rails-dom-testing
          ruby--rails-html-sanitizer))
      (source
        (origin
          (method url-fetch)
          (uri (rubygems-uri "actionpack" version))
          (sha256 (base32 "066p70mngqk8m7qp3wq2frbl1w8imdcrdxb06cxwq5izykcn7hib"))))
      (arguments (list #:ruby ruby #:tests? #f))))
  (define ruby--actiontext
    (gem
      (transformers gem-transformers)
      (name "ruby--actiontext")
      (version "7.1.5.1")
      (propagated-inputs
        (list
          ruby--actionpack
          ruby--activerecord
          ruby--activestorage
          ruby--activesupport
          ruby--globalid
          ruby--nokogiri))
      (source
        (origin
          (method url-fetch)
          (uri (rubygems-uri "actiontext" version))
          (sha256 (base32 "1v7psa946frm79x04vywnd0h069jgxy5xghm7y5sgijvmp7n3qmq"))))
      (arguments (list #:ruby ruby #:tests? #f))))
  (define ruby--actionview
    (gem
      (transformers gem-transformers)
      (name "ruby--actionview")
      (version "7.1.5.1")
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
          (sha256 (base32 "1apnqjfwbvyhf7svlamal1pvy2x78fk42lqbnllqwy816lhrlmcc"))))
      (arguments (list #:ruby ruby #:tests? #f))))
  (define ruby--activejob
    (gem
      (transformers gem-transformers)
      (name "ruby--activejob")
      (version "7.1.5.1")
      (propagated-inputs (list ruby--activesupport ruby--globalid))
      (source
        (origin
          (method url-fetch)
          (uri (rubygems-uri "activejob" version))
          (sha256 (base32 "0rspwfvhxs5by6im90rrjp2sy1wzdpcgb9xm0qfljk3zhmn3fcvn"))))
      (arguments (list #:ruby ruby #:tests? #f))))
  (define ruby--activemodel
    (gem
      (transformers gem-transformers)
      (name "ruby--activemodel")
      (version "7.1.5.1")
      (propagated-inputs (list ruby--activesupport))
      (source
        (origin
          (method url-fetch)
          (uri (rubygems-uri "activemodel" version))
          (sha256 (base32 "1wci45aas8g909zby9j91m87ff5j28qwl0i7izzbszsahmk78wkl"))))
      (arguments (list #:ruby ruby #:tests? #f))))
  (define ruby--activerecord
    (gem
      (transformers gem-transformers)
      (name "ruby--activerecord")
      (version "7.1.5.1")
      (propagated-inputs (list ruby--activemodel ruby--activesupport ruby--timeout))
      (source
        (origin
          (method url-fetch)
          (uri (rubygems-uri "activerecord" version))
          (sha256 (base32 "1qzij5xmsqqxsc9v9kil68aif5bvly06vqf4pnjrnfzkkdhd22pl"))))
      (arguments (list #:ruby ruby #:tests? #f))))
  (define ruby--activestorage
    (gem
      (transformers gem-transformers)
      (name "ruby--activestorage")
      (version "7.1.5.1")
      (propagated-inputs
        (list ruby--actionpack ruby--activejob ruby--activerecord ruby--activesupport ruby--marcel))
      (source
        (origin
          (method url-fetch)
          (uri (rubygems-uri "activestorage" version))
          (sha256 (base32 "0qzz8dxwj70zys1lmqk1x0sl4rb7ddw6v2bgmpm6dijqd03qnsxf"))))
      (arguments (list #:ruby ruby #:tests? #f))))
  (define ruby--activesupport
    (gem
      (transformers gem-transformers)
      (name "ruby--activesupport")
      (version "7.1.5.1")
      (propagated-inputs
        (list
          ruby--base64
          ruby--benchmark
          ruby--bigdecimal
          ruby--concurrent-ruby
          ruby--connection-pool
          ruby--drb
          ruby--i18n
          ruby--logger
          ruby--minitest
          ruby--mutex-m
          ruby--securerandom
          ruby--tzinfo))
      (source
        (origin
          (method url-fetch)
          (uri (rubygems-uri "activesupport" version))
          (sha256 (base32 "1f6gqyl49hdabid5jkrfq0127gd396srsgpy7p5ni61v8wp4h34z"))))
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
  (define ruby--base64
    (gem
      (transformers gem-transformers)
      (name "ruby--base64")
      (version "0.2.0")
      (propagated-inputs (list))
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
      (propagated-inputs (list))
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
      (propagated-inputs (list))
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
      (propagated-inputs (list))
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
      (version "1.2.2")
      (propagated-inputs (list))
      (source
        (origin
          (method url-fetch)
          (uri (rubygems-uri "concurrent-ruby" version))
          (sha256 (base32 "0krcwb6mn0iklajwngwsg850nk8k9b35dhmc2qkbdqvmifdi2y9q"))))
      (arguments (list #:ruby ruby #:tests? #f))))
  (define ruby--connection-pool
    (gem
      (transformers gem-transformers)
      (name "ruby--connection_pool")
      (version "2.5.0")
      (propagated-inputs (list))
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
      (version "3.4.1")
      (propagated-inputs (list))
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
      (version "1.5.0")
      (propagated-inputs (list))
      (source
        (origin
          (method url-fetch)
          (uri (rubygems-uri "diff-lcs" version))
          (sha256 (base32 "0rwvjahnp7cpmracd8x732rjgnilqv2sx7d1gfrysslc3h039fa9"))))
      (arguments (list #:ruby ruby #:tests? #f))))
  (define ruby--docile
    (gem
      (transformers gem-transformers)
      (name "ruby--docile")
      (version "1.4.1")
      (propagated-inputs (list))
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
      (propagated-inputs (list))
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
      (propagated-inputs (list))
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
  (define ruby--io-console
    (gem
      (transformers gem-transformers)
      (name "ruby--io-console")
      (version "0.8.0")
      (propagated-inputs (list))
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
      (propagated-inputs (list ruby--pp ruby--rdoc ruby--reline))
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
  (define ruby--logger
    (gem
      (transformers gem-transformers)
      (name "ruby--logger")
      (version "1.6.6")
      (propagated-inputs (list))
      (source
        (origin
          (method url-fetch)
          (uri (rubygems-uri "logger" version))
          (sha256 (base32 "05s008w9vy7is3njblmavrbdzyrwwc1fsziffdr58w9pwqj8sqfx"))))
      (arguments (list #:ruby ruby #:tests? #f))))
  (define ruby--loofah
    (gem
      (transformers gem-transformers)
      (name "ruby--loofah")
      (version "2.24.0")
      (propagated-inputs (list ruby--crass ruby--nokogiri))
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
      (version "1.0.4")
      (propagated-inputs (list))
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
  (define ruby--mutex-m
    (gem
      (transformers gem-transformers)
      (name "ruby--mutex_m")
      (version "0.3.0")
      (propagated-inputs (list))
      (source
        (origin
          (method url-fetch)
          (uri (rubygems-uri "mutex_m" version))
          (sha256 (base32 "0l875dw0lk7b2ywa54l0wjcggs94vb7gs8khfw9li75n2sn09jyg"))))
      (arguments (list #:ruby ruby #:tests? #f))))
  (define ruby--net-imap
    (gem
      (transformers gem-transformers)
      (name "ruby--net-imap")
      (version "0.5.6")
      (propagated-inputs (list ruby--date ruby--net-protocol))
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
      (version "0.5.1")
      (propagated-inputs (list ruby--net-protocol))
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
      (propagated-inputs (list))
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
      (version "1.18.4")
      (propagated-inputs
        (or
          (match (%current-system) ("x86_64-linux" (list ruby--racc)))
          (error "No supported system found for ~a@~a" "ruby--nokogiri" "1.18.4")))
      (source
        (or
          (match
            (%current-system)
            ("x86_64-linux"
             (origin
               (method url-fetch)
               (uri (list "https://rubygems.org/gems/nokogiri-1.18.4-x86_64-linux-gnu.gem"))
               (sha256 (base32 "07hr6j6xrky5s0sdl9764i9ifma7rl5ahhm3jx77123b6ixl1imi")))))
          (error "No supported system found for ~a@~a" "ruby--nokogiri" "1.18.4")))
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
  (define ruby--pg
    (gem
      (transformers gem-transformers)
      (name "ruby--pg")
      (version "1.5.9")
      (propagated-inputs (list))
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
      (propagated-inputs (list ruby--prettyprint))
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
      (propagated-inputs (list))
      (source
        (origin
          (method url-fetch)
          (uri (rubygems-uri "prettyprint" version))
          (sha256 (base32 "14zicq3plqi217w6xahv7b8f7aj5kpxv1j1w98344ix9h5ay3j9b"))))
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
  (define ruby--psych
    (gem
      (transformers gem-transformers)
      (name "ruby--psych")
      (version "5.2.3")
      (propagated-inputs (list ruby--date ruby--stringio))
      (source
        (origin
          (method url-fetch)
          (uri (rubygems-uri "psych" version))
          (sha256 (base32 "1vjrx3yd596zzi42dcaq5xw7hil1921r769dlbz08iniaawlp9c4"))))
      (arguments (list #:ruby ruby #:tests? #f))))
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
      (version "3.1.12")
      (propagated-inputs (list))
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
      (propagated-inputs (list ruby--base64 ruby--rack))
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
      (propagated-inputs (list ruby--rack))
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
      (propagated-inputs (list ruby--rack))
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
      (version "7.1.5.1")
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
          ruby--railties))
      (source
        (origin
          (method url-fetch)
          (uri (rubygems-uri "rails" version))
          (sha256 (base32 "0148c00v3hks98rymdiilhjm0i8qw5fla4gww0fb94k3ggns5bh5"))))
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
      (version "1.6.2")
      (propagated-inputs (list ruby--loofah ruby--nokogiri))
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
      (version "7.1.5.1")
      (propagated-inputs
        (list
          ruby--actionpack
          ruby--activesupport
          ruby--irb
          ruby--rackup
          ruby--rake
          ruby--thor
          ruby--zeitwerk))
      (source
        (origin
          (method url-fetch)
          (uri (rubygems-uri "railties" version))
          (sha256 (base32 "1yz28fq55drl4c2dwgap96xcjf6qns2ghc3c3gffzm6yw9i5bq8b"))))
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
  (define ruby--rdoc
    (gem
      (transformers gem-transformers)
      (name "ruby--rdoc")
      (version "6.12.0")
      (propagated-inputs (list ruby--psych))
      (source
        (origin
          (method url-fetch)
          (uri (rubygems-uri "rdoc" version))
          (sha256 (base32 "1q2nkyk6r3m15a2an7lwm4ilkcxzdh3j93s4ib8sbzqb0xp70vvx"))))
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
  (define ruby--reline
    (gem
      (transformers gem-transformers)
      (name "ruby--reline")
      (version "0.6.0")
      (propagated-inputs (list ruby--io-console))
      (source
        (origin
          (method url-fetch)
          (uri (rubygems-uri "reline" version))
          (sha256 (base32 "1lirwlw59apc8m1wjk85y2xidiv0fkxjn6f7p84yqmmyvish6qjp"))))
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
  (define ruby--securerandom
    (gem
      (transformers gem-transformers)
      (name "ruby--securerandom")
      (version "0.4.1")
      (propagated-inputs (list))
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
      (propagated-inputs (list ruby--docile ruby--simplecov-html ruby--simplecov-json-formatter))
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
      (propagated-inputs (list))
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
      (propagated-inputs (list))
      (source
        (origin
          (method url-fetch)
          (uri (rubygems-uri "simplecov_json_formatter" version))
          (sha256 (base32 "0a5l0733hj7sk51j81ykfmlk2vd5vaijlq9d5fn165yyx3xii52j"))))
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
  (define ruby--stringio
    (gem
      (transformers gem-transformers)
      (name "ruby--stringio")
      (version "3.1.5")
      (propagated-inputs (list))
      (source
        (origin
          (method url-fetch)
          (uri (rubygems-uri "stringio" version))
          (sha256 (base32 "1j1mgvrgkxhadi6nb6pz1kcff7gsb5aivj1vfhsia4ssa5hj9adw"))))
      (arguments (list #:ruby ruby #:tests? #f))))
  (define ruby--thor
    (gem
      (transformers gem-transformers)
      (name "ruby--thor")
      (version "1.3.2")
      (propagated-inputs (list))
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
      (propagated-inputs (list))
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
      (version "0.7.7")
      (propagated-inputs (list ruby--base64 ruby--websocket-extensions))
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
        ruby--pg
        ruby--properb
        ruby--simplecov)
      (list))))
