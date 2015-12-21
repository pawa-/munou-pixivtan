requires 'perl', '5.20.0';
requires 'Mojolicious';
requires 'EV';
requires 'FindBin';
requires 'Config::Tiny';
requires 'Log::Handler';
requires 'Data::Printer';
requires 'List::AllUtils';
requires 'Net::Twitter::Lite';
requires 'AnyEvent::Twitter::Stream';
requires 'Text::MeCab';
requires 'Unicode::UTF8';
requires 'JSON';
requires 'JSON::XS';
requires 'Lingua::JA::KanjiTable';
requires 'Lingua::JA::NormalizeText';
requires 'Lingua::JA::Halfwidth::Katakana';

on 'test' => sub {
    requires 'Test::More';
};
