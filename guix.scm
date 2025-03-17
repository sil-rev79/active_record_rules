(use-modules (gnu packages)
             (guix build-system ruby)
             (guix gexp)
             (guix download)
             (guix git-download)
             (guix packages)
             (guix transformations)
             (guix utils)
             ((guix licenses)
              #:prefix license:))

(define ruby (specification->package "ruby@3.1"))

(define inputs
  ((load "Gemfile.lock.scm")
   #:ruby ruby
   #:groups '(default)))

(define native-inputs
  ((load "Gemfile.lock.scm")
   #:ruby ruby
   #:groups '(development test)))

(package
 (name "ruby-active_record_rules")
 (version "0.0.1")                      ; for gemspec
 (source
  (local-file "."
              "ruby-active_record_rules-checkout"
              #:recursive? #t
              #:select? (git-predicate (current-source-directory))))
 (build-system ruby-build-system)
 (arguments
  `(#:test-target "spec"))
 (inputs (cons ruby inputs))
 (native-inputs native-inputs)
 (synopsis "Database-driven production rules in Ruby")
 (description
  "A production rule library that uses database records as its
working memory.")
 (license license:gpl3)
 (home-page "https://sr.ht/~czan/active_record_rules/"))
