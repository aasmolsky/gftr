# frozen_string_literal: true

module ParseReviews
  class SignalPresenter
    LABELS = {
      "en" => {
        "THIN_ACCOUNT_0" => "Limited review history",
        "THIN_ACCOUNT_1" => "Sparse review history",
        "SHORT_TEXT_EXTREME" => "Very brief text",
        "SHORT_TEXT" => "Brief text",
        "BURST_AFTER_NEGATIVE" => "Timing pattern noted",
        "FIVE_STAR_EMPTY" => "Short five-star text",
        "SURNAME_REPEAT" => "Similar reviewer names",
        "GENERIC_TEXT" => "Few concrete details",
        "SUSPICIOUS_NEGATIVE" => "Negative review pattern",
        "MARKETING_TONE" => "Promotional wording",
        "ALL_POSITIVE" => "Uniformly positive tone",
        "NO_FIRST_PERSON" => "Impersonal wording",
        "FUTURE_PROMISE" => "Forward-looking wording",
        "BUSINESS_NAME_DROP" => "Business name in text",
        "EMOJI_SPAM" => "Decorative punctuation",
        "TEMPLATE_CLONE" => "Similar phrasing elsewhere",
        "REPEATABLE_PLUSES_2" => "Repeated praise phrasing",
        "REPEATABLE_PLUSES_3" => "Multiple praise phrases",
        "EDITED_REVIEW" => "Edited after posting",
        "HAS_PHOTOS" => "Includes photos",
        "EXPERIENCED_AUTHOR_5" => "Established reviewer",
        "EXPERIENCED_AUTHOR_10" => "Very active reviewer",
        "ACTIVE_PROFILE" => "Active photo profile",
        "LONG_TEXT" => "Detailed write-up",
        "SPECIFIC_DETAILS" => "Concrete details mentioned",
        "BALANCED_TONE" => "Mixed pros and cons",
        "NATURAL_LANGUAGE" => "Natural personal voice",
        "LOCAL_GUIDE" => "Local Guide profile",
        "OWNER_RESPONDED" => "Owner replied",
        "HELPFUL_VOTES" => "Marked helpful by others"
      },
      "ru" => {
        "THIN_ACCOUNT_0" => "Небольшая история отзывов",
        "THIN_ACCOUNT_1" => "Ограниченная история отзывов",
        "SHORT_TEXT_EXTREME" => "Очень короткий текст",
        "SHORT_TEXT" => "Короткий текст",
        "BURST_AFTER_NEGATIVE" => "Отмечен временной паттерн",
        "FIVE_STAR_EMPTY" => "Краткий текст при 5★",
        "SURNAME_REPEAT" => "Похожие фамилии авторов",
        "GENERIC_TEXT" => "Мало конкретики в тексте",
        "SUSPICIOUS_NEGATIVE" => "Подозрительный негативный паттерн",
        "MARKETING_TONE" => "Рекламная подача",
        "ALL_POSITIVE" => "Односторонне положительный тон",
        "NO_FIRST_PERSON" => "Обезличенная формулировка",
        "FUTURE_PROMISE" => "Обещания без деталей визита",
        "BUSINESS_NAME_DROP" => "Название заведения в тексте",
        "EMOJI_SPAM" => "Декоративное оформление текста",
        "TEMPLATE_CLONE" => "Похожая формулировка у других",
        "REPEATABLE_PLUSES_2" => "Повторяющиеся похвалы",
        "REPEATABLE_PLUSES_3" => "Несколько шаблонных похвал",
        "EDITED_REVIEW" => "Редактировался после публикации",
        "HAS_PHOTOS" => "Есть фотографии",
        "EXPERIENCED_AUTHOR_5" => "Автор с историей отзывов",
        "EXPERIENCED_AUTHOR_10" => "Очень активный автор",
        "ACTIVE_PROFILE" => "Активный профиль с фото",
        "LONG_TEXT" => "Развернутый текст",
        "SPECIFIC_DETAILS" => "Есть конкретные детали",
        "BALANCED_TONE" => "Есть и плюсы, и минусы",
        "NATURAL_LANGUAGE" => "Живая личная подача",
        "LOCAL_GUIDE" => "Профиль Local Guide",
        "OWNER_RESPONDED" => "Есть ответ владельца",
        "HELPFUL_VOTES" => "Отмечен как полезный"
      },
      "pl" => {
        "THIN_ACCOUNT_0" => "Ograniczona historia opinii",
        "THIN_ACCOUNT_1" => "Niewielka historia opinii",
        "SHORT_TEXT_EXTREME" => "Bardzo krótki tekst",
        "SHORT_TEXT" => "Krótki tekst",
        "BURST_AFTER_NEGATIVE" => "Zauważony wzorzec czasowy",
        "FIVE_STAR_EMPTY" => "Krótki tekst przy 5★",
        "SURNAME_REPEAT" => "Podobne nazwiska autorów",
        "GENERIC_TEXT" => "Mało konkretów w tekście",
        "SUSPICIOUS_NEGATIVE" => "Podejrzany wzorzec negatywny",
        "MARKETING_TONE" => "Reklamowy ton",
        "ALL_POSITIVE" => "Wyłącznie pozytywny ton",
        "NO_FIRST_PERSON" => "Bezosobowe sformułowania",
        "FUTURE_PROMISE" => "Obietnice bez szczegółów wizyty",
        "BUSINESS_NAME_DROP" => "Nazwa firmy w tekście",
        "EMOJI_SPAM" => "Ozdobna interpunkcja",
        "TEMPLATE_CLONE" => "Podobne sformułowanie u innych",
        "REPEATABLE_PLUSES_2" => "Powtarzające się pochwały",
        "REPEATABLE_PLUSES_3" => "Wiele szablonowych pochwał",
        "EDITED_REVIEW" => "Edytowana po publikacji",
        "HAS_PHOTOS" => "Zawiera zdjęcia",
        "EXPERIENCED_AUTHOR_5" => "Autor z historią opinii",
        "EXPERIENCED_AUTHOR_10" => "Bardzo aktywny autor",
        "ACTIVE_PROFILE" => "Aktywny profil ze zdjęciami",
        "LONG_TEXT" => "Rozbudowany tekst",
        "SPECIFIC_DETAILS" => "Wymienione konkretne szczegóły",
        "BALANCED_TONE" => "Plusy i minusy",
        "NATURAL_LANGUAGE" => "Naturalny, osobisty ton",
        "LOCAL_GUIDE" => "Profil Local Guide",
        "OWNER_RESPONDED" => "Odpowiedź właściciela",
        "HELPFUL_VOTES" => "Oznaczona jako pomocna"
      }
    }.freeze

    def initialize(language)
      @language = normalized_language(language)
    end

    def call(score_breakdown)
      normalize_breakdown(score_breakdown).map do |key, value|
        {
          key: key,
          text: label_for(key),
          kind: value.to_i.positive? ? "negative" : "positive"
        }
      end
    end

    private

    attr_reader :language

    def normalized_language(language)
      base = language.to_s.downcase.split("-").first
      LABELS.key?(base) ? base : "en"
    end

    def normalize_breakdown(value)
      case value
      when Hash
        value
      when Array
        value.each_with_object({}) { |signal, hash| hash[signal[:key]] = signal[:value] }
      else
        {}
      end
    end

    def label_for(key)
      normalized_key = key.to_s
      LABELS.fetch(language, LABELS["en"])[normalized_key] ||
        LABELS["en"][normalized_key] ||
        normalized_key.tr("_", " ").capitalize
    end
  end
end
