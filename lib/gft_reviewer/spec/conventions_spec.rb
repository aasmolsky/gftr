# frozen_string_literal: true

require "frai"

def camelize(value)
  value.split("_").map(&:capitalize).join
end

def task_constant_name(file)
  task_dir = File.basename(File.dirname(file))
  "#{camelize(task_dir)}::Task"
end

def pipeline_constant_name(file)
  base = File.basename(file, ".rb").sub(/_pipeline\z/, "")
  "GftReviewer::#{camelize(base)}Pipeline"
end

RSpec.describe "Project conventions" do
  describe "tasks" do
    Dir[File.join(__dir__, "..", "tasks", "**", "*.rb")]
      .reject { |file| file.include?("/scripts/") }
      .each do |file|
      require file
      next if File.basename(file) == "base_task.rb"

      describe task_constant_name(file) do
        let(:klass) { Object.const_get(task_constant_name(file)) }

        it "inherits from BaseTask" do
          expect(klass.ancestors).to include(BaseTask)
        end

        it "responds to .call" do
          expect(klass).to respond_to(:call)
        end

        it "declares output" do
          expect([:text, :schema, :hash]).to include(klass._output_kind)
        end
      end
    end
  end

  describe "pipelines" do
    Dir[File.join(__dir__, "..", "pipelines", "**", "*.rb")].each do |file|
      require file
      next if File.basename(file) == "base_pipeline.rb"

      describe pipeline_constant_name(file) do
        let(:klass) { Object.const_get(pipeline_constant_name(file)) }

        it "inherits from BasePipeline" do
          expect(klass.ancestors).to include(BasePipeline)
        end

        it "responds to .call" do
          expect(klass).to respond_to(:call)
        end
      end
    end
  end
end
