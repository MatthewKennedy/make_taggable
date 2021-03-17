module MakeTaggable
  module Taggable
    module Calculation
      def count(column_name = :all)
        super(column_name)
      end
    end
  end
end
