const API_URL =
  process.env.NEXT_PUBLIC_API_URL ||
  'http://localhost:3000';


export async function api(
  path:string,
  options:any={}
){

  const token =
    typeof window !== 'undefined'
      ? localStorage.getItem('accessToken')
      : null;


  return fetch(
    `${API_URL}${path}`,
    {

      ...options,

      headers:{
        'Content-Type':'application/json',

        ...(token
          ? {
              Authorization:`Bearer ${token}`
            }
          : {}
        ),

        ...(options.headers || {}),

      },

    }

  );

}