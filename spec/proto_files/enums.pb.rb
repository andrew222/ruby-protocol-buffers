#!/usr/bin/env ruby
# Generated by the protocol buffer compiler. DO NOT EDIT!

require 'protocol_buffers'

module Enums
  # forward declarations

  # enums
  module Foo
    include ::ProtocolBuffers::Enum

    set_fully_qualified_name "enums.Foo"

    ONE = 1
    TWO = 2
    THREE = 3
  end

  module Bar
    include ::ProtocolBuffers::Enum

    # purposfully removing qualified name to make sure nothing breaks
    #set_fully_qualified_name "enums.Bar"

    FOUR = 4
    FIVE = 5
    SIX = 6
  end

end