# Инструкции по интеграции с SearXNG API

Данный документ содержит инструкции по безопасной интеграции SearXNG с сервисами n8n и Flowise.

## Настройка безопасности

SearXNG настроен таким образом, что API доступен **только для внутренних сервисов стека**:

1. **Веб-интерфейс** SearXNG защищен базовой HTTP-аутентификацией
2. **API** доступен только с заголовком `X-API-Source: internal-stack`
3. **CORS** разрешен только для доменов n8n и Flowise

## Учетные данные

Учетные данные для доступа к SearXNG хранятся в файле:
```
/opt/searxng_settings/credentials
```

## Интеграция с n8n

### Создание HTTP-запросов к SearXNG API

В n8n можно создать HTTP-запрос следующим образом:

```javascript
// Узел Function для выполнения запроса к SearXNG API
const searchQuery = items[0].json.query || 'пример запроса';
const apiUrl = `https://searxng.${DOMAIN_NAME}/search`;

// Выполнение запроса с необходимыми заголовками
const response = await $http.request({
  url: apiUrl,
  method: 'GET',
  headers: {
    'X-API-Source': 'internal-stack'  // Важный заголовок для авторизации
  },
  qs: {
    q: searchQuery,
    format: 'json',
    language: 'ru',
    engines: 'google,bing,duckduckgo'  // Можно выбрать необходимые
  }
});

// Обработка результатов
if (response.status === 200 && response.data && response.data.results) {
  // Ограничиваем до 5 результатов
  const results = response.data.results.slice(0, 5).map(result => ({
    title: result.title,
    url: result.url,
    content: result.content || "Описание недоступно"
  }));
  
  return {
    json: {
      success: true,
      searchResults: results
    }
  };
} else {
  return {
    json: {
      success: false,
      error: 'Не удалось получить результаты поиска',
      status: response.status
    }
  };
}
```

## Интеграция с Flowise

### Создание инструмента для доступа к SearXNG

В Flowise необходимо создать собственный инструмент (Custom Tool) для взаимодействия с SearXNG API:

```javascript
const axios = require('axios');

// Функция поиска в SearXNG
async function searchSearXNG(query, options = {}) {
  const {
    language = 'ru',
    engines = 'google,bing,duckduckgo',
    maxResults = 5
  } = options;
  
  try {
    // Формируем URL для запроса
    const apiUrl = `https://searxng.${process.env.DOMAIN_NAME}/search`;
    
    // Выполняем запрос с необходимыми заголовками
    const response = await axios({
      method: 'GET',
      url: apiUrl,
      headers: {
        'X-API-Source': 'internal-stack'
      },
      params: {
        q: query,
        format: 'json',
        language,
        engines
      }
    });
    
    // Проверяем и обрабатываем результаты
    if (response.status === 200 && response.data && response.data.results) {
      const results = response.data.results.slice(0, maxResults);
      
      // Форматируем результаты
      const formattedResults = results.map(result => ({
        title: result.title,
        url: result.url,
        content: result.content || 'Описание недоступно'
      }));
      
      return formattedResults;
    } else {
      throw new Error('Не удалось получить результаты');
    }
  } catch (error) {
    console.error('Ошибка при поиске в SearXNG:', error);
    throw error;
  }
}

// Определение инструмента для Flowise
module.exports = {
  name: 'SearXNG Search',
  description: 'Поиск информации через приватный SearXNG',
  args: {
    query: {
      type: 'string',
      description: 'Поисковый запрос'
    },
    language: {
      type: 'string',
      description: 'Язык поиска (ru, en)',
      default: 'ru'
    },
    engines: {
      type: 'string',
      description: 'Поисковые движки через запятую',
      default: 'google,bing,duckduckgo'
    },
    maxResults: {
      type: 'number',
      description: 'Максимальное количество результатов',
      default: 5
    }
  },
  handler: async ({ query, language, engines, maxResults }) => {
    try {
      const results = await searchSearXNG(query, {
        language,
        engines,
        maxResults: parseInt(maxResults) || 5
      });
      
      if (results.length === 0) {
        return 'По вашему запросу ничего не найдено.';
      }
      
      // Форматируем результаты для вывода
      const formattedResults = results.map((result, index) => 
        `${index + 1}. ${result.title}\n   ${result.url}\n   ${result.content}\n`
      ).join('\n');
      
      return `Результаты поиска:\n\n${formattedResults}`;
    } catch (error) {
      return `Произошла ошибка при поиске: ${error.message}`;
    }
  }
};
```

## Решение проблем

Если возникают проблемы с доступом к API:

1. Проверьте, что заголовок `X-API-Source` правильно установлен
2. Убедитесь, что запрос выполняется с доменов n8n или Flowise
3. Проверьте логи SearXNG:
   ```bash
   sudo docker logs searxng
   ```
4. Проверьте логи Caddy для отслеживания запросов:
   ```bash
   sudo docker logs caddy
   ```
