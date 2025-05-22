<?php

namespace Pterodactyl\Console\Commands;

use Illuminate\Console\Command;
use Pterodactyl\Services\Helpers\SoftwareVersionService;
use Illuminate\Contracts\Config\Repository as ConfigRepository;

class InfoCommand extends Command
{
    protected $description = 'Displays the application, database, and email configurations along with the panel version.';

    protected $signature = 'p:info {--format=text : The output format: "text" or "json". }';

    /**
     * VersionCommand constructor.
     */
    public function __construct(private ConfigRepository $config, private SoftwareVersionService $versionService)
    {
        parent::__construct();
    }

    /**
     * Handle execution of command.
     */
    public function handle()
    {
        $format = $this->option('format');

        $data = [
            'version' => [
                'Panel Version' => $this->config->get('app.version'),
                'Latest Version' => $this->versionService->getPanel(),
                'Up-to-Date' => $this->versionService->isLatestPanel() ? 'Yes' : 'No',
                'Unique Identifier' => $this->config->get('pterodactyl.service.author'),
            ],
            'application' => [
                'Environment' => $this->config->get('app.env'),
                'Debug Mode' => $this->config->get('app.debug') ? 'Yes' : 'No',
                'Installation URL' => $this->config->get('app.url'),
                'Installation Directory' => base_path(),
                'Timezone' => $this->config->get('app.timezone'),
                'Cache Driver' => $this->config->get('cache.default'),
                'Queue Driver' => $this->config->get('queue.default'),
                'Session Driver' => $this->config->get('session.driver'),
                'Filesystem Driver' => $this->config->get('filesystems.default'),
                'Default Theme' => $this->config->get('themes.active'),
                'Proxies' => $this->config->get('trustedproxies.proxies'),
            ],
            'database' => [
                'Driver' => $this->config->get('database.default'),
                'Host' => $this->config->get("database.connections." . $this->config->get('database.default') . '.host'),
                'Port' => $this->config->get("database.connections." . $this->config->get('database.default') . '.port'),
                'Database' => $this->config->get("database.connections." . $this->config->get('database.default') . '.database'),
                'Username' => $this->config->get("database.connections." . $this->config->get('database.default') . '.username'),
            ],
            'email' => [
                'Driver' => $this->config->get('mail.default'),
                'Host' => $this->config->get('mail.mailers.smtp.host'),
                'Port' => $this->config->get('mail.mailers.smtp.port'),
                'Username' => $this->config->get('mail.mailers.smtp.username'),
                'From Address' => $this->config->get('mail.from.address'),
                'From Name' => $this->config->get('mail.from.name'),
                'Encryption' => $this->config->get('mail.mailers.smtp.encryption'),
            ],
        ];

        if ($format === 'json') {
            $this->output->write(json_encode($data, JSON_PRETTY_PRINT | JSON_UNESCAPED_SLASHES));
            $this->output->newLine();

            return 0;
        }
        $this->output->title('Version Information');
        $this->table([], [
            ['Panel Version', $this->config->get('app.version')],
            ['Latest Version', $this->versionService->getPanel()],
            ['Up-to-Date', $this->versionService->isLatestPanel() ? 'Yes' : $this->formatText('No', 'bg=red')],
            ['Unique Identifier', $this->config->get('pterodactyl.service.author')],
        ], 'compact');

        $this->output->title('Application Configuration');
        $this->table([], [
            ['Environment', $this->formatText($this->config->get('app.env'), $this->config->get('app.env') === 'production' ?: 'bg=red')],
            ['Debug Mode', $this->formatText($this->config->get('app.debug') ? 'Yes' : 'No', !$this->config->get('app.debug') ?: 'bg=red')],
            ['Installation URL', $this->config->get('app.url')],
            ['Installation Directory', base_path()],
            ['Timezone', $this->config->get('app.timezone')],
            ['Cache Driver', $this->config->get('cache.default')],
            ['Queue Driver', $this->config->get('queue.default')],
            ['Session Driver', $this->config->get('session.driver')],
            ['Filesystem Driver', $this->config->get('filesystems.default')],
            ['Default Theme', $this->config->get('themes.active')],
            ['Proxies', $this->config->get('trustedproxies.proxies')],
        ], 'compact');

        $this->output->title('Database Configuration');
        $driver = $this->config->get('database.default');
        $this->table([], [
            ['Driver', $driver],
            ['Host', $this->config->get("database.connections.$driver.host")],
            ['Port', $this->config->get("database.connections.$driver.port")],
            ['Database', $this->config->get("database.connections.$driver.database")],
            ['Username', $this->config->get("database.connections.$driver.username")],
        ], 'compact');

        // TODO: Update this to handle other mail drivers
        $this->output->title('Email Configuration');
        $this->table([], [
            ['Driver', $this->config->get('mail.default')],
            ['Host', $this->config->get('mail.mailers.smtp.host')],
            ['Port', $this->config->get('mail.mailers.smtp.port')],
            ['Username', $this->config->get('mail.mailers.smtp.username')],
            ['From Address', $this->config->get('mail.from.address')],
            ['From Name', $this->config->get('mail.from.name')],
            ['Encryption', $this->config->get('mail.mailers.smtp.encryption')],
        ], 'compact');
    }

    /**
     * Format output in a Name: Value manner.
     */
    private function formatText(string $value, string $opts = ''): string
    {
        return sprintf('<%s>%s</>', $opts, $value);
    }
}
