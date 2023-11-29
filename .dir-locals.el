((ruby-mode
  (eglot-server-programs
   ((ruby-mode ruby-ts-mode)
    "solargraph" "stdio"
    :initializationOptions (:formatting t :hover t :definitions t :references t :folding t)))
  (eglot-workspace-configuration
   (solargraph (diagnostics . t)))
  (rspec-use-bundler-when-possible . nil)))
