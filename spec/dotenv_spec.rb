require "spec_helper"

describe Dotenv do
  before do
    Dir.chdir(File.expand_path("../fixtures", __FILE__))
  end

  shared_examples "load" do
    context "with no args" do
      let(:env_files) { [] }

      it "defaults to .env" do
        expect(Dotenv::Environment).to receive(:new).with(expand(".env"))
          .and_return(double(:apply => {}, :apply! => {}))
        subject
      end
    end

    context "with a tilde path" do
      let(:env_files) { ["~/.env"] }

      it "expands the path" do
        expected = expand("~/.env")
        allow(File).to receive(:exist?) { |arg| arg == expected }
        expect(Dotenv::Environment).to receive(:new).with(expected)
          .and_return(double(:apply => {}, :apply! => {}))
        subject
      end
    end

    context "with multiple files" do
      let(:env_files) { [".env", fixture_path("plain.env")] }

      let(:expected) do
        { "OPTION_A" => "1",
          "OPTION_B" => "2",
          "OPTION_C" => "3",
          "OPTION_D" => "4",
          "OPTION_E" => "5",
          "PLAIN" => "true",
          "DOTENV" => "true" }
      end

      it "loads all files" do
        subject
        expected.each do |key, value|
          expect(ENV[key]).to eq(value)
        end
      end

      it "returns hash of loaded environments" do
        expect(subject).to eq(expected)
      end

      it "calls ensure_original_env_saved" do
        expect(Dotenv).to receive(:ensure_original_env_saved).and_return(nil)
        subject
      end
    end
  end

  describe "load" do
    subject { Dotenv.load(*env_files) }

    it_behaves_like "load"

    context "when the file does not exist" do
      let(:env_files) { [".env_does_not_exist"] }

      it "fails silently" do
        expect { subject }.not_to raise_error
        expect(ENV.keys).to eq(@env_keys)
      end
    end
  end

  describe "load!" do
    subject { Dotenv.load!(*env_files) }

    it_behaves_like "load"

    context "when one file exists and one does not" do
      let(:env_files) { [".env", ".env_does_not_exist"] }

      it "raises an Errno::ENOENT error" do
        expect { subject }.to raise_error(Errno::ENOENT)
      end
    end
  end

  describe "overload" do
    let(:env_files) { [fixture_path("plain.env")] }
    subject { Dotenv.overload(*env_files) }
    it_behaves_like "load"

    context "when loading a file containing already set variables" do
      let(:env_files) { [fixture_path("plain.env")] }

      it "overrides any existing ENV variables" do
        ENV["OPTION_A"] = "predefined"

        subject

        expect(ENV["OPTION_A"]).to eq("1")
      end
    end

    context "when the file does not exist" do
      let(:env_files) { [".env_does_not_exist"] }

      it "fails silently" do
        expect { subject }.not_to raise_error
        expect(ENV.keys).to eq(@env_keys)
      end
    end
  end

  context "original environment" do
    describe "ensure_original_env_saved" do
      it "saves the current ENV if not already saved" do
        Dotenv.original_env = nil

        ENV['OPTION_A'] = "1"
        ENV['OPTION_B'] = "2"

        Dotenv.ensure_original_env_saved

        ENV['OPTION_A'] = "10"
        ENV['OPTION_C'] = "30"

        saved_env = Dotenv.original_env

        expect(saved_env["OPTION_A"]).to eq("1")
        expect(saved_env["OPTION_B"]).to eq("2")
        expect(saved_env.has_key?("OPTION_C")).to eq(false)
      end

      it "does nothing if ENV is already saved" do
        Dotenv.original_env = {"OPTION_A" => "1", "OPTION_B" => "2"}
        ENV['OPTION_A'] = "10"
        ENV['OPTION_C'] = "30"

        saved_env = Dotenv.original_env

        expect(saved_env["OPTION_A"]).to eq("1")
        expect(saved_env["OPTION_B"]).to eq("2")
        expect(saved_env.has_key?("OPTION_C")).to eq(false)
      end
    end

    describe "restore_original_env" do
      it "saves ENV if not saved" do
        Dotenv.original_env = nil

        ENV['OPTION_A'] = "1"
        ENV['OPTION_B'] = "2"

        Dotenv.restore_original_env

        saved_env = Dotenv.original_env

        expect(saved_env["OPTION_A"]).to eq("1")
        expect(saved_env["OPTION_B"]).to eq("2")
      end

      it "restores saved env" do
        Dotenv.original_env = {"OPTION_A" => "1", "OPTION_B" => "2"}

        ENV['OPTION_A'] = "10"
        ENV['OPTION_C'] = "30"

        Dotenv.restore_original_env

        expect(ENV["OPTION_A"]).to eq("1")
        expect(ENV["OPTION_B"]).to eq("2")
        expect(ENV.has_key?("OPTION_C")).to eq(false)
      end
    end
  end

  describe "with an instrumenter" do
    let(:instrumenter) { double("instrumenter", :instrument => {}) }
    before { Dotenv.instrumenter = instrumenter }
    after { Dotenv.instrumenter = nil }

    describe "load" do
      it "instruments if the file exists" do
        expect(instrumenter).to receive(:instrument) do |name, payload|
          expect(name).to eq("dotenv.load")
          expect(payload[:env]).to be_instance_of(Dotenv::Environment)
          {}
        end
        Dotenv.load
      end

      it "does not instrument if file does not exist" do
        expect(instrumenter).to receive(:instrument).never
        Dotenv.load ".doesnotexist"
      end
    end
  end

  describe "Unicode" do
    subject { fixture_path("bom.env") }

    it "loads a file with a Unicode BOM" do
      expect(Dotenv.load(subject)).to eql("BOM" => "UTF-8")
    end

    it "fixture file has UTF-8 BOM" do
      contents = File.open(subject, "rb") { |f| f.read }.force_encoding("UTF-8")
      expect(contents).to start_with("\xEF\xBB\xBF")
    end
  end

  def expand(path)
    File.expand_path path
  end
end
