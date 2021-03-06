# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Gitlab::Database::Migrations::BackgroundMigrationHelpers do
  let(:model) do
    ActiveRecord::Migration.new.extend(described_class)
  end

  describe '#bulk_queue_background_migration_jobs_by_range' do
    context 'when the model has an ID column' do
      let!(:id1) { create(:user).id }
      let!(:id2) { create(:user).id }
      let!(:id3) { create(:user).id }

      before do
        User.class_eval do
          include EachBatch
        end
      end

      context 'with enough rows to bulk queue jobs more than once' do
        before do
          stub_const('Gitlab::Database::Migrations::BackgroundMigrationHelpers::BACKGROUND_MIGRATION_JOB_BUFFER_SIZE', 1)
        end

        it 'queues jobs correctly' do
          Sidekiq::Testing.fake! do
            model.bulk_queue_background_migration_jobs_by_range(User, 'FooJob', batch_size: 2)

            expect(BackgroundMigrationWorker.jobs[0]['args']).to eq(['FooJob', [id1, id2]])
            expect(BackgroundMigrationWorker.jobs[1]['args']).to eq(['FooJob', [id3, id3]])
          end
        end

        it 'queues jobs in groups of buffer size 1' do
          expect(BackgroundMigrationWorker).to receive(:bulk_perform_async).with([['FooJob', [id1, id2]]])
          expect(BackgroundMigrationWorker).to receive(:bulk_perform_async).with([['FooJob', [id3, id3]]])

          model.bulk_queue_background_migration_jobs_by_range(User, 'FooJob', batch_size: 2)
        end
      end

      context 'with not enough rows to bulk queue jobs more than once' do
        it 'queues jobs correctly' do
          Sidekiq::Testing.fake! do
            model.bulk_queue_background_migration_jobs_by_range(User, 'FooJob', batch_size: 2)

            expect(BackgroundMigrationWorker.jobs[0]['args']).to eq(['FooJob', [id1, id2]])
            expect(BackgroundMigrationWorker.jobs[1]['args']).to eq(['FooJob', [id3, id3]])
          end
        end

        it 'queues jobs in bulk all at once (big buffer size)' do
          expect(BackgroundMigrationWorker).to receive(:bulk_perform_async).with([['FooJob', [id1, id2]],
                                                                                  ['FooJob', [id3, id3]]])

          model.bulk_queue_background_migration_jobs_by_range(User, 'FooJob', batch_size: 2)
        end
      end

      context 'without specifying batch_size' do
        it 'queues jobs correctly' do
          Sidekiq::Testing.fake! do
            model.bulk_queue_background_migration_jobs_by_range(User, 'FooJob')

            expect(BackgroundMigrationWorker.jobs[0]['args']).to eq(['FooJob', [id1, id3]])
          end
        end
      end
    end

    context "when the model doesn't have an ID column" do
      it 'raises error (for now)' do
        expect do
          model.bulk_queue_background_migration_jobs_by_range(ProjectAuthorization, 'FooJob')
        end.to raise_error(StandardError, /does not have an ID/)
      end
    end
  end

  describe '#queue_background_migration_jobs_by_range_at_intervals' do
    context 'when the model has an ID column' do
      let!(:id1) { create(:user).id }
      let!(:id2) { create(:user).id }
      let!(:id3) { create(:user).id }

      around do |example|
        Timecop.freeze { example.run }
      end

      before do
        User.class_eval do
          include EachBatch
        end
      end

      it 'returns the final expected delay' do
        Sidekiq::Testing.fake! do
          final_delay = model.queue_background_migration_jobs_by_range_at_intervals(User, 'FooJob', 10.minutes, batch_size: 2)

          expect(final_delay.to_f).to eq(20.minutes.to_f)
        end
      end

      it 'returns zero when nothing gets queued' do
        Sidekiq::Testing.fake! do
          final_delay = model.queue_background_migration_jobs_by_range_at_intervals(User.none, 'FooJob', 10.minutes)

          expect(final_delay).to eq(0)
        end
      end

      context 'with batch_size option' do
        it 'queues jobs correctly' do
          Sidekiq::Testing.fake! do
            model.queue_background_migration_jobs_by_range_at_intervals(User, 'FooJob', 10.minutes, batch_size: 2)

            expect(BackgroundMigrationWorker.jobs[0]['args']).to eq(['FooJob', [id1, id2]])
            expect(BackgroundMigrationWorker.jobs[0]['at']).to eq(10.minutes.from_now.to_f)
            expect(BackgroundMigrationWorker.jobs[1]['args']).to eq(['FooJob', [id3, id3]])
            expect(BackgroundMigrationWorker.jobs[1]['at']).to eq(20.minutes.from_now.to_f)
          end
        end
      end

      context 'without batch_size option' do
        it 'queues jobs correctly' do
          Sidekiq::Testing.fake! do
            model.queue_background_migration_jobs_by_range_at_intervals(User, 'FooJob', 10.minutes)

            expect(BackgroundMigrationWorker.jobs[0]['args']).to eq(['FooJob', [id1, id3]])
            expect(BackgroundMigrationWorker.jobs[0]['at']).to eq(10.minutes.from_now.to_f)
          end
        end
      end

      context 'with other_job_arguments option' do
        it 'queues jobs correctly' do
          Sidekiq::Testing.fake! do
            model.queue_background_migration_jobs_by_range_at_intervals(User, 'FooJob', 10.minutes, other_job_arguments: [1, 2])

            expect(BackgroundMigrationWorker.jobs[0]['args']).to eq(['FooJob', [id1, id3, 1, 2]])
            expect(BackgroundMigrationWorker.jobs[0]['at']).to eq(10.minutes.from_now.to_f)
          end
        end
      end

      context 'with initial_delay option' do
        it 'queues jobs correctly' do
          Sidekiq::Testing.fake! do
            model.queue_background_migration_jobs_by_range_at_intervals(User, 'FooJob', 10.minutes, other_job_arguments: [1, 2], initial_delay: 10.minutes)

            expect(BackgroundMigrationWorker.jobs[0]['args']).to eq(['FooJob', [id1, id3, 1, 2]])
            expect(BackgroundMigrationWorker.jobs[0]['at']).to eq(20.minutes.from_now.to_f)
          end
        end
      end
    end

    context "when the model doesn't have an ID column" do
      it 'raises error (for now)' do
        expect do
          model.queue_background_migration_jobs_by_range_at_intervals(ProjectAuthorization, 'FooJob', 10.seconds)
        end.to raise_error(StandardError, /does not have an ID/)
      end
    end
  end

  describe '#perform_background_migration_inline?' do
    it 'returns true in a test environment' do
      stub_rails_env('test')

      expect(model.perform_background_migration_inline?).to eq(true)
    end

    it 'returns true in a development environment' do
      stub_rails_env('development')

      expect(model.perform_background_migration_inline?).to eq(true)
    end

    it 'returns false in a production environment' do
      stub_rails_env('production')

      expect(model.perform_background_migration_inline?).to eq(false)
    end
  end

  describe '#migrate_async' do
    it 'calls BackgroundMigrationWorker.perform_async' do
      expect(BackgroundMigrationWorker).to receive(:perform_async).with("Class", "hello", "world")

      model.migrate_async("Class", "hello", "world")
    end

    it 'pushes a context with the current class name as caller_id' do
      expect(Gitlab::ApplicationContext).to receive(:with_context).with(caller_id: model.class.to_s)

      model.migrate_async('Class', 'hello', 'world')
    end
  end

  describe '#migrate_in' do
    it 'calls BackgroundMigrationWorker.perform_in' do
      expect(BackgroundMigrationWorker).to receive(:perform_in).with(10.minutes, 'Class', 'Hello', 'World')

      model.migrate_in(10.minutes, 'Class', 'Hello', 'World')
    end

    it 'pushes a context with the current class name as caller_id' do
      expect(Gitlab::ApplicationContext).to receive(:with_context).with(caller_id: model.class.to_s)

      model.migrate_in(10.minutes, 'Class', 'Hello', 'World')
    end
  end

  describe '#bulk_migrate_async' do
    it 'calls BackgroundMigrationWorker.bulk_perform_async' do
      expect(BackgroundMigrationWorker).to receive(:bulk_perform_async).with([%w(Class hello world)])

      model.bulk_migrate_async([%w(Class hello world)])
    end

    it 'pushes a context with the current class name as caller_id' do
      expect(Gitlab::ApplicationContext).to receive(:with_context).with(caller_id: model.class.to_s)

      model.bulk_migrate_async([%w(Class hello world)])
    end
  end

  describe '#bulk_migrate_in' do
    it 'calls BackgroundMigrationWorker.bulk_perform_in_' do
      expect(BackgroundMigrationWorker).to receive(:bulk_perform_in).with(10.minutes, [%w(Class hello world)])

      model.bulk_migrate_in(10.minutes, [%w(Class hello world)])
    end

    it 'pushes a context with the current class name as caller_id' do
      expect(Gitlab::ApplicationContext).to receive(:with_context).with(caller_id: model.class.to_s)

      model.bulk_migrate_in(10.minutes, [%w(Class hello world)])
    end
  end
end
