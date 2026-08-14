const configuredApiUrl = process.env.NEXT_PUBLIC_API_URL?.trim();
if (process.env.NODE_ENV === 'production' && (!configuredApiUrl || !configuredApiUrl.startsWith('https://'))) {
  throw new Error('NEXT_PUBLIC_API_URL must be an HTTPS URL in production');
}
const API_URL = configuredApiUrl || 'http://localhost:3000';


export async function api(
  path:string,
  options:any={}
){

  return fetch(
    `${API_URL}${path}`,
    {

      ...options,
      credentials: 'include',

      headers:{
        'Content-Type':'application/json',

        ...(options.headers || {}),

      },

    }

  );

}
