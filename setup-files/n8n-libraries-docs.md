# Библиотеки JavaScript для узла Code в n8n

В данной конфигурации n8n предустановлены дополнительные JavaScript-библиотеки для расширения возможностей узла Code. Ниже приведен список библиотек и примеры их использования.

## Список предустановленных библиотек

### Манипуляции с данными
- **lodash** - утилиты для работы с массивами, объектами и другими структурами данных
- **moment** - библиотека для работы с датами и временем
- **date-fns** - современная альтернатива moment для работы с датами

### HTTP и работа с API
- **axios** - продвинутый HTTP-клиент для выполнения запросов

### Обработка текста и NLP
- **natural** - библиотека для обработки естественного языка
- **string-similarity** - поиск и сравнение строк

### Работа с векторными данными
- **ml-distance** - расчет различных метрик расстояния между векторами
- **@pinecone-database/pinecone** - клиент для Pinecone (векторная БД)

### Парсинг и обработка данных
- **cheerio** - парсинг HTML/XML
- **csv-parser** - обработка CSV-файлов
- **json2csv** - конвертация JSON в CSV
- **fast-xml-parser** - работа с XML
- **xlsx** - работа с Excel-файлами

### Криптография и безопасность
- **crypto-js** - криптографические функции
- **jsonwebtoken** - работа с JWT токенами
- **uuid** - генерация UUID
- **validator** - валидация данных

### Мессенджеры и коммуникации
- **whatsapp-web.js** - работа с WhatsApp

### AI и машинное обучение
- **openai** - официальный клиент OpenAI API
- **langchain** - фреймворк для создания LLM-приложений

### Работа с медиа
- **sharp** - обработка изображений
- **tesseract.js** - OCR (распознавание текста с изображений)
- **pdf-parse** - извлечение текста из PDF-файлов

### Утилиты разработки
- **winston** - логгирование
- **@faker-js/faker** - генерация тестовых данных

## Примеры использования

### Пример 1: Использование lodash и axios

```javascript
// Импорт библиотек в узле Code
const _ = require('lodash');
const axios = require('axios');

// Примеры использования lodash
const items = $input.all();
const groupedItems = _.groupBy(items, 'json.category');
const uniqueValues = _.uniq(items.map(item => item.json.status));

// Пример использования axios с интерцепторами
const api = axios.create({
  baseURL: 'https://api.example.com'
});

api.interceptors.request.use(config => {
  config.headers['Authorization'] = `Bearer ${$env.API_TOKEN}`;
  return config;
});

async function fetchData() {
  try {
    const response = await api.get('/endpoint');
    return { success: true, data: response.data };
  } catch (error) {
    console.error('API Error:', error.message);
    return { success: false, error: error.message };
  }
}

// Возвращаем результат
return await fetchData();
```

### Пример 2: Обработка HTML с cheerio

```javascript
const cheerio = require('cheerio');
const axios = require('axios');

async function scrapeWebsite() {
  const response = await axios.get('https://example.com');
  const $ = cheerio.load(response.data);
  
  const title = $('title').text();
  const paragraphs = [];
  
  $('p').each((i, elem) => {
    paragraphs.push($(elem).text());
  });
  
  return { title, paragraphs };
}

return await scrapeWebsite();
```

### Пример 3: Работа с векторами и embeddings

```javascript
const { cosineDistance } = require('ml-distance').distance;
const { PineconeClient } = require('@pinecone-database/pinecone');

// Функция для расчета косинусного расстояния
function calculateSimilarity(vector1, vector2) {
  // Косинусное сходство = 1 - косинусное расстояние
  return 1 - cosineDistance(vector1, vector2);
}

// Пример работы с Pinecone
async function searchSimilarDocuments(queryVector) {
  const pinecone = new PineconeClient();
  await pinecone.init({
    apiKey: $env.PINECONE_API_KEY,
    environment: 'us-west1-gcp'
  });
  
  const index = pinecone.Index('example-index');
  const queryResponse = await index.query({
    vector: queryVector,
    topK: 10,
    includeMetadata: true
  });
  
  return queryResponse.matches;
}

// Для локального поиска без API
const items = $input.all();
const searchVector = [0.1, 0.2, 0.3, 0.4];
const itemsWithSimilarity = items.map(item => {
  const similarity = calculateSimilarity(item.json.vector, searchVector);
  return { ...item.json, similarity };
});

// Сортировка по сходству
const sortedItems = itemsWithSimilarity.sort((a, b) => b.similarity - a.similarity);

return { json: sortedItems.slice(0, 5) }; // Топ 5 результатов
```

### Пример 4: Обработка дат с moment и date-fns

```javascript
const moment = require('moment');
const { addDays, format, compareAsc } = require('date-fns');

// С использованием moment
function processDatesWithMoment() {
  const now = moment();
  const lastWeek = moment().subtract(7, 'days');
  const formatted = now.format('YYYY-MM-DD HH:mm:ss');
  const daysDiff = now.diff(lastWeek, 'days');
  
  return { now: formatted, daysDiff };
}

// С использованием date-fns (более современный подход)
function processDatesWithDateFns() {
  const now = new Date();
  const nextWeek = addDays(now, 7);
  const formatted = format(now, 'yyyy-MM-dd HH:mm:ss');
  const isInFuture = compareAsc(nextWeek, now) > 0;
  
  return { now: formatted, isInFuture };
}

return {
  moment: processDatesWithMoment(),
  dateFns: processDatesWithDateFns()
};
```

### Пример 5: Генерация тестовых данных с Faker

```javascript
const { faker } = require('@faker-js/faker');

// Генерация тестовых пользователей
function generateUsers(count) {
  const users = [];
  
  for (let i = 0; i < count; i++) {
    users.push({
      id: faker.string.uuid(),
      name: faker.person.fullName(),
      email: faker.internet.email(),
      avatar: faker.image.avatar(),
      registeredAt: faker.date.past(),
      address: {
        street: faker.location.streetAddress(),
        city: faker.location.city(),
        country: faker.location.country()
      }
    });
  }
  
  return users;
}

return { json: generateUsers(10) };
```

## Рекомендации по использованию

1. **Всегда импортируйте библиотеки в начале кода**:
   ```javascript
   const axios = require('axios');
   const _ = require('lodash');
   ```

2. **Обрабатывайте ошибки в асинхронных функциях**:
   ```javascript
   try {
     const result = await someAsyncFunction();
     return { success: true, data: result };
   } catch (error) {
     console.error('Error:', error.message);
     return { success: false, error: error.message };
   }
   ```

3. **Используйте $env для доступа к переменным окружения**:
   ```javascript
   const apiKey = $env.MY_API_KEY;
   ```

4. **Документируйте ваш код с комментариями**:
   ```javascript
   // Эта функция преобразует данные в формат, подходящий для API
   function transformData(data) {
     // Преобразование...
     return transformedData;
   }
   ```

5. **Не злоупотребляйте тяжелыми вычислениями в узле Code** - для сложных или длительных операций лучше использовать внешние сервисы или отдельные узлы n8n.
