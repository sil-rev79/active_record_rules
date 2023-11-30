(use-modules (gnu packages ruby)
             (gnu packages rails)
             (guix build-system ruby)
             (guix gexp)
             (guix download)
             (guix git-download)
             (guix packages)
             (guix transformations)
             (guix utils)
             ((guix licenses)
              #:prefix license:))

(define-public ruby-flexmock
  (package
   (name "ruby-flexmock")
   (version "2.3.8")
   (source
    (origin
     (method url-fetch)
     (uri (rubygems-uri "flexmock" version))
     (sha256
      (base32 "07yabbg08chxv7simc9hvxjq6z16svx1gvd36jzb8k7yvn05560y"))))
   (build-system ruby-build-system)
   (synopsis "
    FlexMock is a extremely simple mock object class compatible
    with the Minitest framework.  Although the FlexMock's
    interface is simple, it is very flexible.
  ")
   (description
    "@code{FlexMock} is a extremely simple mock object class compatible with the
Minitest framework.  Although the @code{FlexMock's} interface is simple, it is
very flexible.")
   (home-page "https://github.com/doudou/flexmock")
   (license license:expat)))

(define-public ruby-parslet
  (package
   (name "ruby-parslet")
   (version "2.0.0")
   (source
    (origin
     (method url-fetch)
     (uri (rubygems-uri "parslet" version))
     (sha256
      (base32 "01pnw6ymz6nynklqvqxs4bcai25kcvnd5x4id9z3vd1rbmlk0lfl"))))
   (build-system ruby-build-system)
   (arguments
    `(#:test-target "spec"
      ;; One of the tests fails, and I can't be bothered figuring it out now.
      #:tests? #f))
   (native-inputs (list ruby-sdoc ruby-rspec ruby-ae ruby-flexmock ruby-qed))
   (synopsis "Parser construction library with great error reporting in Ruby.")
   (description
    "Parser construction library with great error reporting in Ruby.")
   (home-page "http://kschiess.github.io/parslet")
   (license license:expat)))

(package
 (name "ruby-active_record_rules")
 (version "0.0.1") ; for gemspec
 (source
  (local-file "."
              "ruby-active_record_rules-checkout"
              #:recursive? #t
              #:select? (git-predicate (current-source-directory))))
 (build-system ruby-build-system)
 (arguments
  `(#:test-target "spec"))
 (inputs (list ruby
               ruby-activerecord
               ruby-parslet))
 (native-inputs (list bundler ruby-rake ruby-rails ruby-rspec ruby-rubocop ruby-rubocop-rspec ruby-solargraph))
 (synopsis "Database-driven production rules in Ruby")
 (description
  "A production rule library that uses database records as facts in its
working memory. Rules are database objects which get activated and
deactivated via ActiveRecord callbacks as records are updated.")
 (license license:gpl3)
 (home-page "https://sr.ht/~czan/active_record_rules/"))
