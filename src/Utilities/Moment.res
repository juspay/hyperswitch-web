// Moment.js bindings for date formatting utilities
type t

@module("moment") external make: Date.t => t = "default"
@send external format: (t, string) => string = "format"
