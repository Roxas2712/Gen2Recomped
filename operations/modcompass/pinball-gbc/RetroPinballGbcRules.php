<?php
// Original GBC edition contract, contributions by Roxas2712.
// Integrate through the existing server's shared friend/device/wire checks.
declare(strict_types=1);
namespace App\Services;
use InvalidArgumentException;

final class RetroPinballGbcRules
{
    public const EDITION = 'pinballgbc';
    public const ROM = '9402014d14969432142abfde728c6f1a10ee4dac';
    public const RUNTIME = '743f52e73ec5cc90478b3591632406ac7764b45c';

    public static function supports(mixed $edition): bool
    {
        return $edition === self::EDITION;
    }

    private static function require(bool $ok, string $message): void
    {
        if (! $ok) {
            throw new InvalidArgumentException($message);
        }
    }

    private static function keys(array $value, array $keys): void
    {
        $actual = array_keys($value);
        sort($actual);
        sort($keys);
        self::require($actual === $keys, 'Unexpected GBC Pinball rule fields.');
    }

    public static function presence(array $value): array
    {
        self::keys($value, ['protocol', 'field', 'frames', 'locale']);
        self::require($value['protocol'] === 1 && in_array($value['field'], [0, 1], true)
            && $value['frames'] === 18000 && $value['locale'] === 'en', 'Invalid GBC Pinball presence.');
        return $value;
    }

    public static function fingerprint(array $rules): string
    {
        return hash('sha256', implode("\n", ['pinball-duel-v1', $rules['rom'], $rules['backend'], $rules['content']]));
    }

    public static function validate(array $rules, string $fingerprint): array
    {
        self::keys($rules, ['protocol', 'field', 'frames', 'seed', 'rom', 'backend', 'content', 'locale']);
        self::presence(array_intersect_key($rules, array_flip(['protocol', 'field', 'frames', 'locale'])));
        self::require($rules['seed'] === 0 && $rules['rom'] === self::ROM
            && $rules['content'] === 'USA-'.self::ROM, 'Different GBC Pinball cartridge or content.');
        self::require(is_string($rules['backend']) && preg_match('/\Agbrecompiled-'.self::RUNTIME.'-[a-f0-9]{16}\z/D', $rules['backend']) === 1,
            'Invalid GBC Pinball native build identity.');
        self::require(preg_match('/\A[a-f0-9]{64}\z/D', $fingerprint) === 1
            && hash_equals(self::fingerprint($rules), $fingerprint), 'GBC Pinball fingerprint does not match its rules.');
        return $rules;
    }
}
